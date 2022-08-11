# Images

## Overview

This folder contains classes for handling images.

Range app uses [`Kingfisher`](https://github.com/onevcat/Kingfisher) library for caching images.

The cache(s) are configured in the `Images` class. There are 2 caches:

1. `localPhotosCache` - this is a not expiring disk cache for images that are pending upload. This could be as well refactored to directly storing images on disk if needed (and not use Kingfisher)

2. `downloadsCache` - this is the default cache used for displaying images - this is where the images are cached and fetched from for setting in a UIImageView


## Uploading photos

When the `FirebasePendingUploadsModel` creates a new pending upload it will store the image and it's thumbnail (produced locally in the app) in the `localPhotosCache`

Once the image is uploaded the image and the thumbnail data will be moved to `downloadsCache`


## Displaying images

When displaying images the app use `Kingfisher` extensions to `UIImageView` that accepts an `ImageDataProvider` - a Kingfisher concept of customizable data source for images (instead of fetching images by URL - which is the default way).

Range implements the custom `FirebaseStorageImageProvider` that can be obtained for given `Upload` from the `Images` and deals with fetching the image directly from the firebase storage (using storage references, not URLs). 

As a fallback the `FirebaseStorageImageProvider` checks if the image can be fetched from `localPhotosCache` - to handle the case where the image is not uploaded yet.


 

