# Docker Operations

CYBEROPS discovers immediate subdirectories beneath `STACK_ROOT` (default
`/srv/stacks`) containing `compose.yml`, `compose.yaml`, `docker-compose.yml`,
or `docker-compose.yaml`.

## Update workflow

1. Discover Compose projects.
2. Select one, several, or all projects.
3. Display every selected file and planned command.
4. Pull images and run `docker compose up -d --remove-orphans`.
5. Retry startup once after `RETRY_DELAY` when necessary.
6. Check running, stopped, one-shot, replacement-container, and health state.
7. Display recent logs for failures and continue with the remaining projects.
8. Write a private recovery report and display the maintenance summary.
9. Offer image pruning separately only when every selected project succeeds.

Completed one-shot containers are accepted only when their exit status is `0`.
Container IDs are refreshed while health converges so replacements are checked
instead of superseded containers.

Recovery reports use mode `600` beneath
`${XDG_STATE_HOME:-$HOME/.local/state}/cyberops/docker/`. They record Compose
files, services, containers, image references and IDs, runtime state, exit
codes, and health. Environment values are intentionally excluded.

## Manual recovery

CYBEROPS never attempts automatic rollback. Images can introduce application
or database migrations that an image change alone cannot safely reverse.

After a failed update:

1. Do not prune images.
2. Open the recovery report shown in the summary.
3. Compare the `BEFORE` and `AFTER` image IDs and runtime state.
4. Inspect the project without mutation:

   ```bash
   docker compose -f /path/to/compose.yml ps --all
   docker compose -f /path/to/compose.yml logs --tail 80 --no-color
   ```

5. Follow the application's documented backup and recovery procedure.
6. Only when application documentation confirms an image-only rollback is
   safe, retag the recorded previous image and recreate without pulling:

   ```bash
   docker image tag <before-image-id> <recorded-image-reference>
   docker compose -f /path/to/compose.yml up -d --no-build --pull never --remove-orphans
   ```

Restoring an image does not restore volumes, databases, bind mounts, Compose
configuration, secrets, or schema changes.

## Configuration

| Setting | Default | Accepted value |
| --- | --- | --- |
| `STACK_ROOT` | `/srv/stacks` | Safe absolute path other than `/`, without `.` or `..` traversal components |
| `RETRY_DELAY` | `5` | Integer from 0 to 3,600 seconds |
| `HEALTH_TIMEOUT` | `120` | Integer from 1 to 86,400 seconds |
| `HEALTH_INTERVAL` | `5` | Integer from 1 to 3,600 seconds and no greater than `HEALTH_TIMEOUT` |
| `FAILURE_LOG_LINES` | `80` | Integer from 1 to 10,000 |
| `DRY_RUN` | `0` | `0` for execution or `1` for preview |

Invalid configuration exits with status 2 before the interactive menu opens.

Use `cyberops docker status` for non-interactive, read-only container and disk
usage telemetry. Docker update and prune operations remain interactive.
