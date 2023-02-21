# Media Store

## Overview

This folder contains classes for media files downloaded from Storage and added locally on the device.

Range app uses [`Kingfisher`](https://github.com/onevcat/Kingfisher) library for caching images.
It also uses Kingfisher for local files storage (although that's an implementation detail hidden behind the `LocalFiles` class)

1. `localPhotosCache` - this is a not expiring disk cache for images that are pending upload. This could be as well refactored to directly storing images on disk if needed (and not use Kingfisher)

2. `downloadsCache` - this is the default cache used for displaying images - this is where the images are cached and fetched from for setting in a UIImageView


## Uploading media

The files to be uploaded are stored using `LocalFiles`.

`LocalFiles` is implemented using not-expiring disk cache stored in the "Application Support" directory, so it's not cleaned up by the system when cleaning caches.

When the `FirebasePendingUploadsModel` creates a new pending upload it will also store its thumbnails (if it's an image) (produced locally in the app) in the `LocalFiles`

Once the image is uploaded the image and the thumbnail data will be moved to `MediaCache`


## Downloading media

`MediaCache` is a way to download media from Storage and cache locally in an expiring cache.

When displaying images the app use `Kingfisher` extensions to `UIImageView` that accepts an `ImageDataProvider` - a Kingfisher concept of customizable data source for images (instead of fetching images by URL - which is the default way).

Range implements the custom `FirebaseStorageImageProvider` that can be obtained for given `MediaKey` from the `MediaCache` and deals with fetching the image directly from the firebase storage (using storage references, not URLs). 

As a fallback the `FirebaseStorageImageProvider` checks if the image can be fetched from `LocalFiles` - to handle the case where the image is not uploaded yet.


 

