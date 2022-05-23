# Description

This folder handles adding a Photo to the map and placing it via pins, including the ability
to attach a photo to an already-existing pin.

There's a lot of subtlety to this interaction.

After you take a photo, your first choice is simply to use the last location, which makes
it easy to take multiple photos quickly.

Otherwise, if you want the photo attached to a location that's NOT the last one, you can
place it by moving the map behind a pin that appears in the center of the view. This pin
shows a thumbnail of your photo as you move the map.

However, because you're likely to want to place your new pin at an existing location, the
map shows all the pins you've already placed, and if you move the map so that your new pin
is on top of an existing pin, the photo thumbnail disappears and is replaced by a 
highlighted pink pin representing the "old" location you'd like to attach the photo to.

The old locations are Range geometries stored in Firebase.

## Files

### AddPhotoConfirmationViewController

Confirmation view that you want to accept or cancel your in-progress photo placement

### AddPhotoPinsHandler

The main logic to associate a just-taken photo with either a new or existing photo pin.
Associates data from Firebase with pins in Mapbox.

#### Firebase/Mapbox interaction

While, technically, photos will be attached to a Range Collaboration, since the pins are
shown using Mapbox, we have no choice but to find pin locations using Range Geometries 
(which are the only objects that have lat/lng positions). Right now, each Geometry 
has exactly one Feature which has exactly one Collaboration.

Geometries are stored in Firebase and read in order to create Mapbox pins 
(using Mapbox PointAnnotations)

#### SelectedPin

Defines the data associated with the selected pin (simply: id and point) and is
instantiated from a Mapbox PointAnnotation or Turf Feature


### AddPhotoTopViewController

A simple view at the top of the screen showing "Add Location"

### PanAndZoomIndicatorView

A simple "toast" view that says "Pan and zoom to adjust the location" at the bottom 
of the screen as you're deciding where to place your photo

