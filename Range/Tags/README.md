# Tags

## Overview

This folder handles the UI for tags:
- displaying tags for given model Results<Tag>
- selection of tags when adding a photo using `TagsViewModel`


## Displaying `Tag`s

The main class is `TagsView`

## Selection of tags when adding photo 

2 main UI classes are:

1. `TagsSelectionViewController` - displays tags in a table view using `TagSelectionTableViewCell` as cells
2. `SelectedTagsViewController` - displays a horizontally scrollable collection of selected tags using `TagCollectionViewCell` as cells

The UI operates on a view model defined in the `TagsViewModel` class that stores tags 
and their selection and provides a way to notify delegates about selection changes.
