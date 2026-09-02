<!--
  Title: CONSUL (demokratie.today)
  Description: Citizen Participation and Open Government Application
  Keywords: democracy, citizen participation, eparticipation, debates, proposals, voting, consultations, crowdlaw, participatory budgeting
-->

# CONSUL — demokratie.today

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](http://www.gnu.org/licenses/agpl-3.0)

This is the [demokratie.today](https://demokratie.today) fork of CONSUL — the open-source
citizen-participation and open-government platform originally built for the Madrid City
government and now maintained upstream as
[Consul Democracy](https://github.com/consuldemocracy/consuldemocracy).

CONSUL lets public institutions run online participation processes: debates, citizen
proposals, voting, consultations, collaborative legislation (crowdlaw) and participatory
budgeting. This fork is heavily customized for the requirements of German municipalities —
project-based participation, German authentication providers (BundID, BayernID),
GDPR-by-default configuration and the KERN UX standard for the administration backend.

> **Note:** This is an independent product. It is **not** kept in sync with the upstream
> Consul Democracy repository; treat upstream documentation as background only.

Four German-language documents accompany this repository: the
[Architektur](ARCHITEKTUR.md) overview (components and how they interact), the
[Betriebshandbuch](BETRIEBSHANDBUCH.md) (hosting, deployment, backups, monitoring), the
[Third-Party Notices](THIRD_PARTY_NOTICES.md) (major open-source components and licenses)
and the [Security Policy](SECURITY.md) (responsible disclosure of vulnerabilities).
Machine-readable software-directory metadata (openCoDE) lives in
[publiccode.yml](publiccode.yml).

## Development setup

Prerequisites: `git`, **Ruby 3.1.4**, **Node.js 20.11.0**, PostgreSQL, CMake,
`pkg-config`, `shared-mime-info` and ImageMagick.

```bash
git clone git@github.com:hanuschka/consul.git
cd consul
bundle install
npm install
cp config/database.yml.example config/database.yml
cp config/secrets.yml.example config/secrets.yml
bin/rake db:create
bin/rake db:schema:load
bin/rake db:dev_seed
RAILS_ENV=test bin/rake db:setup
```

> A fresh database loads the committed `db/schema.rb` (`db:schema:load`) rather than
> replaying migrations from zero. Some historical migrations introspect current models, so
> a from-zero `db:migrate` does not run cleanly on an empty database; `schema.rb` is the
> authoritative source.

Run the app locally:

```bash
bin/rails s
```

Run the tests:

```bash
bin/rspec
```

The seed data includes a default admin user (already verified, so it can do everything):

> **user:** admin@consul.dev
> **pass:** Aa12345678

`db:dev_seed` also creates users for every role at the same password (`Aa12345678`) —
e.g. `mod@consul.dev`, `manager@consul.dev`, `valuator@consul.dev`, `verified@consul.dev`,
`unverified@consul.dev`.

## Production setup

A production deploy needs Ruby, Rails, PostgreSQL, Nginx, Puma, SMTP, Memcached,
DelayedJob, HTTPS (Let's Encrypt) and Capistrano. The steps below set this up manually.

### Manual installation

These steps assume a clean **Ubuntu 22.04 or 24.04** server with `root`/`sudo` access. All
application commands run as the unprivileged `deploy` user, from the app directory
(`/home/deploy/consul/current` once Capistrano is in use, or wherever you check the code
out for a first deploy).

#### 1. Create the deploy user

```bash
adduser --disabled-password deploy
usermod -aG sudo deploy
# allow passwordless sudo for the deploy user (Capistrano/maintenance)
echo 'deploy ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/deploy
```

Add your SSH public key to `/home/deploy/.ssh/authorized_keys` and log in as `deploy` for
the remaining steps.

#### 2. System packages

```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y \
  build-essential cron tmux vim htop git-core wget curl \
  zlib1g-dev libssl-dev libreadline-dev libyaml-dev \
  libxml2-dev libxslt1-dev libffi-dev libcurl4-openssl-dev \
  libpq-dev imagemagick ruby-dev shared-mime-info policykit-1 \
  libgeos-dev proj-bin pandoc
```

#### 3. PostgreSQL

```bash
sudo apt-get install -y postgresql postgresql-contrib python3-psycopg2
sudo systemctl enable --now postgresql

# create the deploy DB role and database
sudo -u postgres createuser --encrypted deploy
sudo -u postgres createdb --owner deploy consul_production

# enable the extensions CONSUL relies on, in a dedicated schema
sudo -u postgres psql -d consul_production <<'SQL'
CREATE SCHEMA IF NOT EXISTS shared_extensions AUTHORIZATION deploy;
CREATE EXTENSION IF NOT EXISTS plpgsql;
CREATE EXTENSION IF NOT EXISTS unaccent  SCHEMA shared_extensions;
CREATE EXTENSION IF NOT EXISTS pg_trgm   SCHEMA shared_extensions;
SQL
```

PostgreSQL should listen on `localhost` only; do not expose port 5432 externally.

#### 4. Ruby and Node

Install the exact versions pinned in the repo (`.ruby-version` → **3.1.4**,
`.node-version` → **20.11.0**). Use whichever version managers you prefer; the examples
below use RVM for Ruby and `fnm` for Node:

```bash
# Ruby (RVM)
\curl -sSL https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm
rvm install "$(cat .ruby-version)"

# Node (fnm)
curl -fsSL https://fnm.vercel.app/install | bash
fnm install "$(cat .node-version)"
```

#### 5. Application code and dependencies

```bash
git clone git@github.com:hanuschka/consul.git /home/deploy/consul/current
cd /home/deploy/consul/current
git checkout a14            # the release tag you deploy to production

bundle config set --local path 'vendor/bundle'
bundle config set --local without 'development test'
bundle install

fnm exec npm install --production
```

#### 6. Configuration and secrets

```bash
cp config/secrets.yml.example   config/secrets.yml
cp config/database.yml.example  config/database.yml

# generate a production secret_key_base
bin/rake secret
```

`config/secret_emails.yml` is gitignored and has no example, but it is **required** for
deployment: Capistrano lists it under `:linked_files`, so `cap deploy` fails if
`shared/config/secret_emails.yml` does not exist. You must create it. It is a
newline-separated allowlist of "partner" email addresses; a single placeholder address
(`admin@consul.dev`) is enough to start.

Edit `config/secrets.yml` for the `production` environment:

- set `secret_key_base` to the value generated above,
- set `server_name` to your domain,
- keep `force_ssl: true`,
- fill in the SMTP block under `smtp_settings` (see **Email** below),
- set `http_basic_username` / `http_basic_password` (and `http_basic_auth`) if you want to
  password-protect the site.

Set the database name / host / user / password in `config/database.yml`, pointing the
`production` environment at the `consul_production` database created in step 3.

#### 7. Load schema, seed and precompile

A fresh production database loads the committed `db/schema.rb` rather than replaying
migrations from zero (see the note in the development section — a from-zero `db:migrate`
does not run cleanly). Capistrano runs `db:migrate` on later deploys once the schema is in
place.

```bash
RAILS_ENV=production bin/rake db:schema:load
RAILS_ENV=production bin/rake db:seed
RAILS_ENV=production bin/rake assets:precompile
RAILS_ENV=production bundle exec whenever --update-crontab
```

#### 8. Application server (Puma)

Run Puma as a systemd service bound to a UNIX socket that Nginx proxies to. Create
`/etc/systemd/system/puma.service` (adjust paths/worker counts to the box), then:

```bash
sudo systemctl enable --now puma
```

#### 9. Web server (Nginx) and HTTPS

```bash
sudo apt-get install -y nginx python3-certbot-nginx
```

Configure an Nginx vhost that proxies to the Puma socket, then obtain a certificate
(renewal is handled automatically by `certbot.timer`):

```bash
sudo certbot --nginx --expand -d your-domain.example
```

#### 10. Background jobs and cache

```bash
# Memcached
sudo apt-get install -y memcached
sudo systemctl enable --now memcached
```

Run DelayedJob workers as systemd instances. Install a template unit at
`/etc/systemd/system/delayed_job@.service` and start one instance per worker:

```bash
sudo systemctl enable --now delayed_job@1 delayed_job@2
sudo systemctl status 'delayed_job@*'
```

#### 11. Subsequent deploys (Capistrano)

After the first release, new code is shipped with Capistrano from your local machine.
`config/deploy.rb` already sets `repo_url` to `https://github.com/hanuschka/consul.git` and
defines the `production`, `staging` and `preproduction` stages. Per-target deploy settings
(`deploy_to`, `ssh_port`, server IP, user) live in `config/deploy-secrets/` (gitignored,
one file per client). The ref to ship — a branch or release tag — is chosen with the
`branch` env var (Capistrano resolves it through `git rev-parse`, so a tag works too):

```bash
branch=a14 cap production deploy
```

> See `config/deploy.rb` for how the per-client secrets file is selected.

### Email

CONSUL sends mail asynchronously through the DelayedJob queue. Configure SMTP in the
`production` block of `config/secrets.yml`:

```yaml
mailer_delivery_method: "smtp"
smtp_settings:
  :address:              "smtp.example.com"
  :port:                 "587"
  :domain:               "your-domain.example"
  :user_name:            "username"
  :password:             "password"
  :authentication:       "plain"
  :enable_starttls_auto: true
```

Because mail is queued, SMTP misconfiguration surfaces in the worker logs rather than as a
500 error. Inspect the last failure from the Rails console:

```bash
RAILS_ENV=production bin/rails runner 'puts Delayed::Job.last&.last_error'
```

## License

Code published under AFFERO GPL v3 (see [LICENSE](LICENSE)).

## Contributions

See [CONTRIBUTING.md](CONTRIBUTING.md).
