# Tags

## Overview

This folder handles the UI for tags:
- displaying tags for given model Results<Tag>
- selection of tags when adding a photo using `TagsViewModel`


## Displaying `Tag`s

The main class is `TagsView`

## Selection of tags when adding photo 

Main UI classes are:

1. `TagsSelectionViewController` - displays tags in a table view using `TagSelectionTableViewCell` as cells
2. `SelectedTagsViewController` - displays a horizontally scrollable collection of selected tags using `TagCollectionViewCell` as cells
3. `SearchAndSelectTagsHeaderViewController` - a header view composed of search view and `SelectedTagsViewController`. The "header" denotes that it's being used as a header in views that support header expanding.
4. `SearchAndSelectTagsViewController` - card view for editing tags for given `TagsViewModel`. Composed of the `SearchAndSelectTagsHeaderViewController` and `TagsSelectionViewController`. Supports header expanding. Does not support card interaction, so user cannot interact with the card (to minimize it for example). The reason is that we still need to implement support for simultaneous non modal card display and header expanding (as they both rely on handling panning and scrolling the header/content view)

The UI operates on a view model defined in the `TagsViewModel` class that stores tags 
and their selection and provides a way to notify delegates about selection changes.
