# Model


## Overview

This folder handles the Range iOS app model.

There are 2 main parts of the model:

1. The local database for storing all model objects
2. A mechanism to synchronize the local database with the Firebase backend

There is an **important** assumption that the app should not be aware of Firebase being used as the mechanism to synchronize local and backend data. In other words - the UI should operate on the local database and have no dependencies to Firebase.

## Topics

### Main classes

- `ProjectModel` - entry point for local Realm-based storage of project data
- `ProjectSummary`, `PDFCanvas`, ... - Realm objects representing Range model concepts
- `CustomPersistable` - support for custom types not supported natively by Realm Swift SDK
- `Firebase/`
  - `ProjectModelFirebaseSync` - entry point for Realm <-> Firebase synchronization
  - `Firebase*` (e.g. `FirebaseProjectSummary`) - structs modelling the Firebase data, used to decode from Firebase representation to Realm objects 
  
### Geometry

Range geometry (from the backend model) is represented as a `Geometry` class but...
Mapbox is using `Geometry` as an alias for `Turf.Geometry` but it shouldn't be too confusing (?)


### Local database

For local storage Range iOS app uses [Realm database](https://www.mongodb.com/docs/realm/sdk/swift/)

Each Range project is stored in a separate Realm - see the `ProjectModel` class for details.

The Range iOS app will use Realm SDK features that allow to add/modify/remove objects from the database as well as observe the changes in the database.

To check the contents of the database while developing and running the app on the simulator use the [Realm Studio](https://www.mongodb.com/docs/realm-legacy/products/realm-studio.html) app to open the Realm file. The Realm file path is logged in the console when starting the app - please note that path changes with each simulator run.

### Offline usage

Once the data is stored in the Realm it'll be available there for offline usage.

Any changes made in the iOS app will be stored in the Realm, so they are immediately available in the UI, but will be marked as required syncing, so the Firebase synchronizer can update the backend appropriately. The synchronization can run immediately after updates if user is online (or on Wifi) or later if the user is offline while making the changes.


### Firebase synchronization

The entry point for Firebase synchronization is the `ProjectModelFirebaseSync` class.

It is used for doing the initial sync of project (`doInitialSync` method) and then starting the synchronization of changes.

The initial sync is required to complete at least once before the project can be open, so the UI can rely on the fact that the project data is available in the local db (it wouldn't make sense to show project if fetching project summary or canvases failed). Once it's done the subsequent runs of the app can use the offline data stored in Realm.

