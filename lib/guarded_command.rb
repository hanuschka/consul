require "open3"

# Runs an external binary with the guards a user-facing upload path needs: no
# shell, a wall-clock deadline, an address-space cap, and a ceiling on how much
# output is kept. The realistic threat is a crafted document rather than a bug —
# a PDF that makes the converter spin or allocate without bound would otherwise
# hang a worker for as long as the queue allows.
#
# Callers get a result object instead of an exception: a document that defeats
# the converter should degrade to "we could not read this", never to a failed
# job.
module GuardedCommand
  DEFAULT_TIMEOUT = 20.seconds
  DEFAULT_MEMORY_LIMIT = 1.gigabyte
  DEFAULT_OUTPUT_LIMIT = 1.megabyte

  # Long enough for a reader to notice the closed pipe, short enough that a
  # wedged thread cannot hold the caller.
  READER_JOIN_TIMEOUT = 2.seconds

  # How long a terminated process gets to exit before it is killed outright.
  TERM_GRACE = 2.seconds

  Result = Struct.new(:stdout, :stderr, :timed_out, :exit_status, keyword_init: true) do
    def success?
      !timed_out && exit_status == 0
    end

    def failure_reason
      return "timed out" if timed_out
      return "could not be started" if exit_status.nil?

      "exited with status #{exit_status}"
    end
  end

  def self.run(
    *command,
    timeout: DEFAULT_TIMEOUT,
    memory_limit: DEFAULT_MEMORY_LIMIT,
    output_limit: DEFAULT_OUTPUT_LIMIT
  )
    stdout_buffer = +""
    stderr_buffer = +""
    timed_out = false
    exit_status = nil

    Open3.popen3(*command, **spawn_options(memory_limit)) do |stdin, stdout, stderr, wait_thread|
      stdin.close

      readers = [
        capped_reader(stdout, stdout_buffer, output_limit),
        capped_reader(stderr, stderr_buffer, output_limit)
      ]

      if wait_thread.join(timeout).nil?
        timed_out = true
        terminate(wait_thread.pid)
        wait_thread.join
      end

      readers.each { |reader| reader.join(READER_JOIN_TIMEOUT) }
      exit_status = wait_thread.value&.exitstatus
    end

    Result.new(
      stdout: stdout_buffer,
      stderr: stderr_buffer,
      timed_out: timed_out,
      exit_status: exit_status
    )
  rescue StandardError => e
    Rails.logger.warn("[GuardedCommand] #{command.first} failed to run: #{e.class}: #{e.message}")

    Result.new(stdout: "", stderr: e.message, timed_out: false, exit_status: nil)
  end

  # pgroup: true so a converter that forks takes its children down with it.
  #
  # Darwin defines RLIMIT_AS but rejects setrlimit on it, and a rejected spawn
  # would fail every command outright, so the cap is applied only where it
  # works. Staging and production are Linux; the local macOS dev box runs
  # without it and keeps the timeout and output cap.
  def self.spawn_options(memory_limit)
    options = { pgroup: true }
    return options if memory_limit.blank?
    return options if !linux?

    options.merge(rlimit_as: memory_limit)
  end

  def self.linux?
    return @linux if !@linux.nil?

    @linux = RbConfig::CONFIG["host_os"].to_s.include?("linux")
  end

  # Reading continues past the cap and discards the surplus: stopping outright
  # would fill the pipe buffer and block the child until the deadline, turning
  # every chatty command into a timeout.
  def self.capped_reader(stream, buffer, limit)
    Thread.new do
      while (chunk = stream.read(4096))
        remaining = limit - buffer.bytesize
        buffer << (remaining >= chunk.bytesize ? chunk : chunk.byteslice(0, remaining)) if remaining > 0
      end
    rescue IOError
      nil
    end
  end

  def self.terminate(pid)
    Process.kill("TERM", -pid)
    return if wait_for_exit(pid)

    Process.kill("KILL", -pid)
  rescue Errno::ESRCH
    nil
  end

  def self.wait_for_exit(pid)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + TERM_GRACE

    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      return true if Process.waitpid(pid, Process::WNOHANG)

      sleep 0.05
    end

    false
  rescue Errno::ECHILD
    true
  end
end
