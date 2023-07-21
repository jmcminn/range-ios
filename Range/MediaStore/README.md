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

## MediaCache vs storage version vs offline mode
 
StorageVersion is a server side feature - when file is uploaded to Storage it gets a new `metadata.generation` which we then store in `Upload` document.
 
MediaCache requires MediaKey with storageVersion, so all files are stored with given version to support image versioning.
 
When uploading files from the device they are stored in LocalFiles and added to pending uploads. 
We still want to display the images (and their thumbnails) and documents while they're waiting to be uploaded 
(potentially long time if user is offline). For this to happen MediaCache checks first in LocalFiles before downloading from Firestore.

 - When checking LocalFiles storage version is not used, as it is not know until uploaded
 - But we still need some storage version to use for MediaKey - in this case we store a random UUID as the storage version - it's not actually used because at this stage the file is only accessed from a LocalFiles, it's more of a HACK so the rest of the app can treat all the Uploads in the same way (using MediaCache)

When local file is uploaded to Firestore we store the it's `generation` (only for the main file, thumbnails are not uploaded) in `Upload.localStorageVersion` and move the files from LocalFiles to MediaCache (using the main generation for the **main file and thumbnails**)

- this allows to immediately show the uploaded files to user without waiting to download them from cache
- `localStorageVersion` is there to keep the information about the storage version (which is always required to access MediaCache) in case if it's not yet available in the `Upload` object (when file is uploaded it'll take some time to populate the main version and even longer to generate thumbnails and populate their storage versions)

