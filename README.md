## About

`ciep` stands for "Container Image EntryPoint".

`ciep` is approach to be extensible and customizable "`docker-entrypoint.sh`" variant/replacement.

If you have problems with it then feel free to open the issue/PR. :)

*NB: work in progress.*

---

## Usage:

Example Dockerfile for Alpine Linux - [Dockerfile.alpine](Dockerfile.alpine)

### In short

With (base) container image:

- add `ciep.sh` and `ciep.d/` to root directory
- create directory `/ciep.user` and set it as volume (recommended)
- set entrypoint to `/ciep.sh`
- install `dumb-init` and `su-exec` (recommended)

With derivative container image:

- (optional) add files to `/ciep.d/`

With resulting container:

- (optional) bind mount directory with custom scripts to "`/ciep.user/`"
- (optional) setup variables `CIEP_*`

### Quick example run:

With Docker:

```sh
docker run --rm \
  -e CIEP_RUNAS=123:1234 \
  -v "$PWD/ciep.sh:/ciep.sh:ro" \
  -v "$PWD/example-ciep.d:/ciep.d:ro" \
alpine:latest \
sh -c 'apk --update add dumb-init su-exec; echo; exec /ciep.sh sh -c "id; echo; ps; echo; env"'
```

Output:

```
fetch https://dl-cdn.alpinelinux.org/alpine/v3.16/main/x86_64/APKINDEX.tar.gz
fetch https://dl-cdn.alpinelinux.org/alpine/v3.16/community/x86_64/APKINDEX.tar.gz
(1/2) Installing dumb-init (1.2.5-r1)
(2/2) Installing su-exec (0.2-r1)
Executing busybox-1.35.0-r17.trigger
OK: 6 MiB in 16 packages

uid=123(ntp) gid=1234 groups=1234

PID   USER     TIME  COMMAND
    1 ntp       0:00 dumb-init sh -c id; echo; ps; echo; env
   19 ntp       0:00 sh -c id; echo; ps; echo; env
   21 ntp       0:00 ps

CIEP_RUNAS_USER=ntp
CIEP_RUNAS_GROUP=1234
USER=ntp
HOSTNAME=55e5618b1e5b
SHLVL=3
HOME=/var/empty
LOGNAME=ntp
CIEP_RUNAS=123:1234
TERM=xterm
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
TESTENV=gotcha_example.envsh
SHELL=/sbin/nologin
PWD=/
```

## Details:

### Environment:

- `CIEP_VERBOSE` - messages from `ciep`:
  - (*empty*) (default) - print only "verbose" messages;
  - (*any non-empty value*) - print regular messages along with "verbose" messages;

- `CIEP_ENV` - "env only" mode:
  - (*empty*) (default) - run as usual;
  - (*any non-empty value*) - run only `*.envsh` scripts;

  NB: if first command line argument is `env` then "env only" mode is **enforced**.

  This mode may be useful in cases like "attaching to existing container" to achieve same environment, e.g.:

  ```sh
  docker exec -it my_container /ciep.sh env <command>
  ```

- `CIEP_INIT` - PID1 handling:
  - (*empty*) (default) - defaults to `"dumb-init"` if `ciep.sh` is running as pid 1 (i.e. starting container);
                          otherwise defaults to `"no"`;
  - `no`, `false` or `0` - don't handle PID1;
  - `"init_cmd"` - try handling PID1 with `"init_cmd"`:

    `"init_cmd"` is being split value by spaces, 1st value is used as `"init_binary"` name and rest values are used as arguments (if any);

    if `"init_binary"` isn't found - don't handle PID1.

- `CIEP_RUNAS` - user/group switching (before running actual command):
  - (*empty*) (default) - don't switch user/group;
  - `user` - try switch user to "`user`" using `su-exec`;

    if `su-exec` isn't found - don't switch;

  - `user:group` - try switch user to "`user`" and group to "`group`" using `su-exec`;

    if `su-exec` isn't found - don't switch;

  - `user:group:runas_cmd` - try switch user to "`user`" and group to "`group`" using `"runas_cmd"`;

    `"runas_cmd"` is being split value by spaces, 1st value is used as `"runas_binary"` name and rest values are used as arguments (if any);

    if `"runas_binary"` isn't found - don't switch.

### File handling:

`ciep.sh` looks for files in both directories `/ciep.d/` and `/ciep.user/` simultaneously.

Hovewer, files in `/ciep.user/` take over against `/ciep.d/`.

Few notes about file naming:

- files named like `"*.-"` are "local override markers" and always skipped without running them;

  if there's file named `"/ciep.user/${filename}.-"` then neither `"/ciep.d/${filename}"` nor  `"/ciep.user/${filename}"` will be sourced or run.

  Example message from `ciep.sh`:

  ```
  # /ciep.sh: local ignore: /ciep.d/script is suppressed by /ciep.user/script.-
  ```

- files named like `"*.envsh"` are considered to be shell scripts to be sourced by `ciep.sh`;

- other executable files are run.

### Conventions for files in /ciep.{d,user}/:

Shell scripts:

- (except `*.envsh`) source `/ciep.sh` first:

  ```sh
  #!/bin/sh
  . /ciep.sh
  ```

- `*.envsh` scripts: avoid changing `CIEP_*` variables unless really required;
- `*.envsh` scripts: **STRONGLY** avoid changing `__CIEP_*` variables;
- use shell function `log()` to output regular messages;
- use shell function `log_verbose()` to output messages to catch user attention;
- use shell function `have_cmd()` to check "binary" (file with executable bit set) availability;

Non-shell scripts/binaries (only recommendations):

- handle (as necessary) command line arguments that were initially provided to `/ciep.sh`;
- prefix output messages with `"${__CIEP_SOURCE}: "`;
- output messages to `stderr`.

---

## License

Apache-2.0

- [spdx.org](https://spdx.org/licenses/Apache-2.0.html)
- [opensource.org](https://opensource.org/licenses/Apache-2.0)
- [apache.org](https://www.apache.org/licenses/LICENSE-2.0)
