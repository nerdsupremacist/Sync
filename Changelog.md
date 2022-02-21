# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2022-02-20
## Fixed
- Fixed UI update issues when using `Sync`
- Fixed projected value of `SyncedObject` not being visible


## [1.0.0] - 2022-02-20
### Added
- Added `valueChange` publisher to `Synced`, to listen for changes to the value
- Added getter for `connection` to `SyncedObject`
- Added support for getting a `SyncedObbject` from a parent `SyncedObject` via dynamic member lookup 
- Added `SyncManager.reconnect` method to restard connection
- Added `ReconnectionStrategy` in order to attempt to resume the session after being disconnected

## Changed
- **Breaking:** Renamed `SyncedObject` protocol to `SyncableObject`. To be consistent with `ObservableObject`
- **Breaking:** Renamed `SyncedObservedObject` to `SyncedObject`. To be consistent with `ObservedObject`
- **Breaking:** Projected Value of `SyncedObject` is of type now `SyncedObject`
- **Breaking:** Renamed `SyncableObject.manager` to `sync`
- **Breaking:** Renamed `SyncableObject.managerWithoutRetainingInMemory` to `syncWithoutRetainingInMemory`

## [0.1.0] - 2022-02-21
### Added
- Support for OpenCombine

### Changed
- Improved handling of updates to array


## [0.1.0] - 2022-02-20
### Added
- Initial Release
