# Photo annotations

## Scribble tool

### data format

there’s no format really (yet), I just store bezier lines (which on iOS is a wrapper for both, multilines with straight lines and curved lines)

- the next step is to try and store it as SVG and present some proposal in this matter

### Polyline simplification

The polyline based on points from user pan gesture is

1. simplified to reduce the number of polyline segments using the Douglas-Peucker algorithm. Simplification gives better results for interpolation (and reduces unnecessary big number of segments caused by user gesture)

2. interpolated with bezier curves using Catmull-Rom algorithm. Interpolation makes the drawing looks smooth

- The parameters for both algorithms were chosen experimentally.
- Both steps are not really required to get it work

### Scribble view scaling

The scribble views are scaled down because otherwise the app would run out of memory pretty soon and the performance of drawing a shape on a view of size 3000x4000 points is very bad.

- This scaling is only done for the purpose of the iOS annotations editor, so it’ll not have effect on the resulting annotations (generated SVG, etc.)
- it does lower the resolution of scribbles in the iOS annotations editor, so the final annotations (when rendering one image containing all annotations) will have scribbles in higher resolution