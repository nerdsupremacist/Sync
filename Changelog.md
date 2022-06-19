# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - Unreleased
### Added
- Added default Message Pack based event coding context. 
- Connections no longer need to specify a coding context. It will use the Message Pack Context by default.
- Added `EventBus`, which acts like `Synced`, except it only allows to send messages, and won't persist any values.
- Added `SyncedWriteRights`, which will 

### Changed
- **Breaking Compatibility with 1.1.0:** Changes to strings are now encoded into smaller changes, reducing the size of transmission. But this change makes it incompatible with 1.1.0 since the payloads transmitted have now changed.
- **Breaking Compatibility with 1.1.0:** Other changes in internals event encoding/decoding which make this version not compatible with 1.1.0. Please make sure that you upgrade all usages at the same time.

## [1.1.0] - 2022-02-27
### Added
- Added projected value to `Synced` property wrapper, to access value change publisher
- Exporting imports of Combine/OpenCombine

## [1.0.1] - 2022-02-21
### Fixed
- Fixed compiler errors on non Apple Platforms

## [1.0.1] - 2022-02-20
### Fixed
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
