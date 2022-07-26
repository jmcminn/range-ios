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
  - `ProjectModelFirestoreSync` - entry point for Realm <-> Firestore synchronization
  - `Firebase*` (e.g. `FirebaseProjectSummary`) - structs modelling the Firebase data, used to decode from Firebase representation to Realm objects and for generating commands for upserting data into Realm
  
### Model classes names

Range geometry/feature (from the backend model) are represented as a `Geometry`/`Feature` classes but...
Mapbox is using `Geometry`/`Feature` as aliases for `Turf.Geometry`/`Turf.Feature` but it shouldn't be too confusing (?)


### Local database

For local storage Range iOS app uses [Realm database](https://www.mongodb.com/docs/realm/sdk/swift/)

Each Range project is stored in a separate Realm - see the `ProjectModel` class for details.

The Range iOS app will use Realm SDK features that allow to add/modify/remove objects from the database as well as observe the changes in the database.

To check the contents of the database while developing and running the app on the simulator use the [Realm Studio](https://www.mongodb.com/docs/realm-legacy/products/realm-studio.html) app to open the Realm file. The Realm file path is logged in the console when starting the app - please note that path changes with each simulator run.

### Offline usage

Once the data is stored in the Realm it'll be available there for offline usage.

Any changes made in the iOS app will be stored in the Realm, so they are immediately available in the UI, but will be marked as required syncing, so the Firebase synchronizer can update the backend appropriately. The synchronization can run immediately after updates if user is online (or on Wifi) or later if the user is offline while making the changes.


### Firebase synchronization

The entry point for Firebase synchronization is the `ProjectModelFirestoreSync` class.

The synchronization starts by calling the `start` function, which first does (and awaits) for the initial sync (`doInitialSync` method) and then starts observing the firestore collection references.

The initial sync is required to complete at least once before the project can be open, so the UI can rely on the fact that the project data is available in the local db (it wouldn't make sense to show project if fetching project summary or canvases failed). Once it's done the subsequent runs of the app can use the offline data stored in Realm.

#### Firebase paths to Realm objects

Each interesting firebase ref is observed using `ProjectModelFirestoreSync.syncDetails` function, which accepts a type that implements the Swift `Codable` protocol (so it can decode from Firebase) and also the custom `FirestoreToRealmSyncable` which associates the type with a Realm object type and provides an implementation of upserting it in the Realm db.

So for example `FirebaseGeometry` class provides implementation of decoding `geometries` from Firebase and upserting `Geometry` into Realm db.

