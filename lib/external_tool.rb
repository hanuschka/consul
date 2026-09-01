# Answers "is this command line tool installed" by walking PATH rather than
# running the tool. A page render must not spawn a process per tool, and every
# converter spells its version flag differently, so a lookup that needs no
# per-tool knowledge is both cheaper and simpler to extend.
module ExternalTool
  def self.installed?(command)
    path_for(command).present?
  end

  def self.path_for(command)
    return nil if command.blank?

    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |directory|
      next if directory.blank?

      candidate = File.join(directory, command)
      return candidate if File.file?(candidate) && File.executable?(candidate)
    end

    nil
  end
end
