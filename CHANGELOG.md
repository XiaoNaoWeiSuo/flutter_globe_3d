## 2.0.1

### 正式稳定版，不兼容旧版本

此版本是 `flutter_globe_3d` 的正式稳定版，解决了所有已知的 bug 和问题。
**重要提示：此版本与之前的 `1.x.x` 版本不兼容。** 开发者在升级时请注意代码迁移。

### 亮点

- 解决了所有已知的渲染、交互和性能问题。
- 优化了内部代码结构，提高了可维护性。
- 增加了详细的源码注释，方便开发者理解和使用。

## 1.2.2

* Fix: Globe be move to bottom one radius in Listview,Fixed.

## 1.2.1

* Fix: Adjust container and globe size ratio to 1:1.5 (sphere:frame) for better visual balance
* Fix: Align markers and connection lines to globe surface with correct positioning offset

## 1.2.0

### Highlights

- Fix: Unify auto-rotation control so `EarthController.autoRotate` is the single
	source of truth. User interactions (drag/scale) temporarily disable auto-rotate
	and the controller restores it when idle.
- Fix: Remove `ImageStream` listener on texture load error as well as on success
	to avoid leaking listeners when image decoding fails.
- Fix: Properly stop and start the internal physics ticker when an
	`EarthController` instance is swapped on the widget. This prevents duplicate
	tickers and unexpected behavior when the controller is replaced.
- Feature: Add two configuration flags in `EarthConfig`:
	- `polarLock` — when true, vertical rotation (pitch) is disabled (no polar tilt).
	- `zoomLock` — when true, programmatic or gesture zoom changes are ignored.

### Details & Migration Notes

- Auto-rotate
	- Previous versions sometimes split auto-rotate state between the widget and
		the controller which could lead to inconsistent behavior after interactions.
		In 1.2.0 the widget defers to `EarthController.autoRotate` only. If you
		previously relied on widget-local flags, migrate to the controller API:

```dart
final controller = EarthController(autoRotate: true);

// Pause auto-rotate during custom interaction
controller.autoRotate = false;

// Resume
controller.autoRotate = true;
```

- Polar / Zoom locks
	- To lock vertical rotation (prevent the globe from tilting), set
		`EarthConfig(polarLock: true)`. To disable zooming set
		`EarthConfig(zoomLock: true)`. Example:

```dart
final controller = EarthController(
	config: const EarthConfig(polarLock: true, zoomLock: false),
);
```

- Image/load safety
	- The texture loader now removes image stream listeners on both success and
		error paths. No change is required by consumers, but this prevents a class
		of listener-leak bugs that could surface when an image fails to decode.

- Controller lifecycle
	- When swapping `EarthController` instances on a `Flutter3DGlobe` widget, the
		old controller's physics ticker is stopped and the new controller's ticker
		is started. This prevents multiple active tickers if the controller is
		replaced at runtime.

### Notes

- This release is currently unreleased; the public package version and
	publish steps will be performed when you are ready. The codebase has been
	updated to target `1.2.0` locally, but you can continue to iterate on
	behavior before publishing.

### Changelog (summary)

- Fix: Keep auto-rotation consistent after user interaction (restore controller.autoRotate)
- Fix: Remove image stream listener on texture load error to avoid leaks
- Fix: Properly stop/start physics when `EarthController` instance is swapped


## 1.1.5

* Fix: Stuttering caused by scaling

## 1.1.4

* Fix: layout/display defect — component now adapts to arbitrary dynamic layouts (ListView, Column, Row, Stack, etc.)
* Update: example and README, add demo GIFs and screenshots

## 0.1.4

* Change the example,add some display gif

## 0.0.4

* Fix the problem that the frag file cannot be found,Remove the assets label

## 0.0.3

* Fix the problem that the frag file cannot be found again

## 0.0.2

* Fix the problem that the frag file cannot be found

## 0.0.1

* Initial release of the 3D Globe widget