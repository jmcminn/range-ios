# Tags

## Overview

This folder handles the UI for tags selection.

2 main UI classes are:

1.  `TagsViewController` - displays tags in a table view using `TagTableViewCell` as cells
2. `SelectedTagsViewController` - displays a horizontally scrollable collection of selected tags using `TagCollectionViewCell` as cells

The UI operates on a view model defined in the `TagsViewModel` class that stores tags and their selection and provides a way to notify delegates about selection changes.

`TagsHandler` is a controller that coordinates between tags `SearchView` for entering search terms and the UI view controllers to display the tags.

