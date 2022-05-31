# Logging

## Overview
 
The app is using Apple os Logger for logging.

The levels to use are (see [docs](https://developer.apple.com/documentation/os/logging/generating_log_messages_from_your_code) for more details):

- Debug - development messages
- Info - not essential for troubleshooting
- Default - the default level to use in logs that is essential for troubleshooting
- Error - unexpected error
- Fault - probable bugs in code, for example named image could not be load (so it's probably missing in the app assets)

The `Logger` has more methods, but they are just duplicates for the above mentioned. 



## Reading logs

There's multiple ways to read logs

1. Logs are displayed in the Xcode Console - they're not marked with levels and there's no way to limit the level

2. macOS Console.app can be used to view the logs - it shows the logs no matter if the app is started from the Xcode or not - useful for viewing logs when the app starts in background, etc. To enable Info/Debug logs go to `Action` / `Include Info/Debug Messages`. There's a bug that currently doesn't show Debug logs from the simulator. 

3. `log` command can be used to stream the simulator logs in the console:
```xcrun simctl spawn booted log stream  --predicate 'subsystem == "io.range.App"' --level debug --style compact```
(source: [apple dev forum thread](https://developer.apple.com/forums/thread/82736))



When viewing the logs in the Console.app or `log` it's recommended to limit the subsystem to the one used by the app, which is: `io.range.App`.

## Links

- [Apple logging docs](https://developer.apple.com/documentation/os/logging)
- [An article on Logger usage](https://www.avanderlee.com/debugging/oslog-unified-logging/)