# f0_extrema.praat

[![DOI](https://zenodo.org/badge/199961157.svg)](https://zenodo.org/badge/latestdoi/199961157)

A Praat script to find peaks and valleys in F0 contours.

## Purpose
Find peaks and valleys, collectivelly called extreme points, in f0 and f0 velocity contours.

## Input
In "Multiple files" mode, a folder containing any number of Pitch files and another folder with corresponding TextGrid files with user-added segmentation.
 
In "Single file" mode, one Pitch file and its corresponding TextGrid. The complete path and file name (extension included) of Pitch and TextGrid should be informed by the user in the GUI menu: "Pitch path" and "Grid path" fields.

## Output
In "Multiple files", the script outputs a report listing all extreme points for each Pitch-TextGrid pair in the folders defined by the user. The full path and name of the report file should be specified at the "Report" field in the script initial form.

In "Single file" mode, the script outputs two Sound objects and one TextGrid object. The Sound objects contain two channels, the first one is the smooth f0 contour and the second the f0 velocity contour. One Sound object has the values in Hz and the other in the OctaveMedian scale. The TextGrid has three tiers: boundaries in the interval range defined by the user; extreme points in f0 contour; extreme points in f0 velocity contour.

To better view the contours in the Sound objects, go to View > Sound scaling > Scaling strategy and choose "by window and channel".

## Changelog

See the [CHANGELOG](CHANGELOG.md) file for the complete version history.

## License

See the [LICENSE](LICENSE.md) file for license rights and limitations.


## How to cite

Click on the DOI badge above to see instructions on how to cite the script.
