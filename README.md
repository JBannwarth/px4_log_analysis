# PX4 Log Analysis

Scripts to analyse PX4 logs

J.X.J. Bannwarth

## How to use

### Importing logs from SD card

Run `ImportLogs`, it will copy and rename the ulog files from your SD card.

### Plotting responses for a log

Run `FlightOverview` to plot the responses for the most recent imported log.
For older logs, first run `LoadLog(logName)` and then run `FlightOverview`.

For example:

```matlab
[flog, ulog] = LoadLog( fullfile( '2021-02-08', '2021-02-08_15-29-40_posctl.ulg' ) );
FlightOverview
```

Note that if you do not specify the subfolder when using `LoadLog`, the
logs folder and its subfolders are searched for a matching file. Therefore,

```matlab
[flog, ulog] = LoadLog( fullfile( '2021-02-08', '2021-02-08_15-29-40_posctl.ulg' ) );
```

and

```matlab
[flog, ulog] = LoadLog( '2021-02-08_15-29-40_posctl.ulg' );
```

will yield the same results.

### Generating PDF report for a log

Run `GenerateFlightReport` without any arguments for the most recent log.
For older logs, indicate the file in the first argument.

For example:

```matlab
GenerateFlightReport( fullfile( '2021-02-08', '2021-02-08_15-29-40_posctl.ulg' ) )
```

The generated report will be written in the `reports` subfolder, and will
open upon completion.