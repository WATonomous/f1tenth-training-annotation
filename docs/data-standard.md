# Data Standard

Version: 1.0

This document defines the sample, metadata, annotation, provenance, and prediction
formats used by every part of this repository. Extraction, validation, labeling,
review, and training code must read and write data in exactly these formats.

Changes to this document require lead approval and a version bump. Every JSON file
carries the `schema_version` it was written against.

## Contents

1. [Conventions](#1-conventions)
2. [Identifiers](#2-identifiers)
3. [Directory layout](#3-directory-layout)
4. [RGB/depth pairing](#4-rgbdepth-pairing)
5. [Image files](#5-image-files)
6. [Session metadata](#6-session-metadata-sessionjson)
7. [Sample metadata](#7-sample-metadata-metasample_idjson)
8. [Detection annotations](#8-detection-annotations)
9. [Segmentation annotations](#9-segmentation-annotations)
10. [Annotation provenance](#10-annotation-provenance)
11. [Predictions](#11-predictions)
12. [Validation rules](#12-validation-rules)
13. [Examples](#13-examples)

## 1. Conventions

| Item | Convention |
| --- | --- |
| Timestamps | Integer nanoseconds since the Unix epoch, taken from the ROS message `header.stamp` (capture time), never the bag receive time. Field names end in `_ns`. |
| Dates and times | ISO 8601 in UTC, e.g. `2026-10-08T10:12:00Z`. |
| Distances | Metres in JSON (`_m` suffix). Depth images are in millimetres (Section 5). |
| Pixel coordinates | Continuous coordinates: the image spans `[0, W] x [0, H]`, origin at the top-left, x right, y down. `_px` suffix. |
| Normalised coordinates | Pixel coordinates divided by image width (x) or height (y). `n` suffix, e.g. `bbox_xywhn`. |
| Camera frame | RGB camera optical frame: x right, y down, z forward, metres. |
| Member IDs | GitHub username. |
| Tool IDs | `<tool-name>@<version>`, e.g. `yolo-autolabel@0.2.0`. |
| JSON | UTF-8, 2-space indent, no comments. Unknown or unavailable values are `null`, never omitted. |

## 2. Identifiers

### 2.1 Session ID

A session is one continuous recording with one camera, one calibration, and one
environment. A change of camera, resolution, calibration, or environment starts a
new session.

```
<date>_<location>_<run>
```

| Field | Format | Example |
| --- | --- | --- |
| `date` | `YYYYMMDD`, local date at the start of recording | `20261006` |
| `location` | lowercase letters, digits, and hyphens; no underscores | `e7-hallway`, `tube-track` |
| `run` | `r` + two digits, counting from `r01` for each date/location pair | `r03` |

Regex: `^\d{8}_[a-z0-9]+(-[a-z0-9]+)*_r\d{2}$`

Example: `20261006_e7-hallway_r03`

### 2.2 Sample ID

A sample is one RGB frame paired with one depth frame. The sample ID links the
RGB image, depth image, annotations, metadata, and source session.

```
<session_id>_<frame>
```

`frame` is a six-digit, zero-padded index, e.g. `000412`.

Regex: `^\d{8}_[a-z0-9]+(-[a-z0-9]+)*_r\d{2}_\d{6}$`

Example: `20261006_e7-hallway_r03_000412`

Rules:

- Indices are assigned at first extraction, counting from `000000` over the
  valid pairs of the session in RGB timestamp order.
- Once assigned, a sample ID is permanent. It is never renumbered, reused, or
  reassigned to a different frame.
- Re-extraction matches frames to existing sample IDs by `rgb_timestamp_ns`.
  Newly added pairs get the next unused index. Order samples by
  `rgb_timestamp_ns`, not by index.
- The session ID is the sample ID with the last `_<frame>` removed.

### 2.3 Track ID

A positive integer, unique within a session. The global identity of a vehicle
track is `(session_id, track_id)`. Track IDs are defined in Section 8.4.

## 3. Directory layout

All data lives under `src/data/` (`DATA_DIR`). Each session gets its own
directory, and every per-sample file is named `<sample_id>.<ext>`.

```
src/data/
├── recordings/
│   └── <session_id>/                 # rosbag2 MCAP, kept unchanged
├── datasets/
│   └── <session_id>/
│       ├── session.json              # session metadata (Section 6)
│       ├── tracks.json               # box attributes and track IDs (Section 8.4)
│       ├── rgb/<sample_id>.png       # Section 5.1
│       ├── depth/<sample_id>.png     # Section 5.2
│       ├── labels/<sample_id>.txt    # YOLO boxes (Section 8.3)
│       ├── masks/<sample_id>.png     # drivable-area mask (Section 9.1)
│       └── meta/<sample_id>.json     # sample metadata and provenance (Section 7)
└── predictions/
    └── <run_id>/
        ├── run.json                  # Section 11.1
        └── <session_id>/
            ├── detections.jsonl      # Section 11.2
            ├── masks/<sample_id>.png # Section 11.3
            └── probs/<sample_id>.png # optional, Section 11.3
```

Rules:

- `rgb/`, `depth/`, and `meta/` hold one file for every sample.
- `labels/` and `masks/` hold a file only when that annotation type exists
  (Section 10.3).
- Training code builds framework-specific views (e.g. an Ultralytics
  `images/` + `labels/` tree) from this layout with symlinks or file lists. It
  never moves, renames, or modifies dataset files.

## 4. RGB/depth pairing

Every sample must have both RGB and depth. A frame without a valid partner is not
a sample.

| Rule | Value |
| --- | --- |
| Anchor stream | RGB (colour) |
| Partner selection | Depth frame with the nearest `header.stamp` |
| Maximum difference | `|depth_timestamp_ns - rgb_timestamp_ns| <= 10_000_000` (10 ms) |
| Uniqueness | Each depth frame pairs with at most one RGB frame. If two RGB frames select the same depth frame, the closer pair is kept and the other RGB frame is dropped. |
| Rejected frames | Get no sample ID. Counted in `session.json` under `pairing`. |
| Depth registration | Depth is aligned to the RGB camera, at RGB resolution. Pixel `(u, v)` in depth corresponds to pixel `(u, v)` in RGB. |
| Alignment source | Use the driver's aligned topic (`aligned_depth_to_color`) when it was recorded. Otherwise extraction aligns raw depth using the recorded intrinsics and depth-to-colour extrinsics. `session.json` records which was used. |

`pair_dt_ns` is stored signed, as `depth_timestamp_ns - rgb_timestamp_ns`.

## 5. Image files

RGB and depth for a sample have identical width and height. Images are stored at
the captured resolution and are not resized, cropped, or undistorted.

### 5.1 RGB

| Property | Value |
| --- | --- |
| Path | `rgb/<sample_id>.png` |
| Format | PNG, 8-bit, 3 channels, RGB order |
| Source | Decoded colour frame. If the bag holds compressed colour images, the PNG holds the decoded frame and `session.json` records the source encoding. |

OpenCV reads PNGs as BGR. Convert to RGB before use.

### 5.2 Depth

| Property | Value |
| --- | --- |
| Path | `depth/<sample_id>.png` |
| Format | PNG, 16-bit unsigned, 1 channel |
| Units | Millimetres (1 unit = 0.001 m) |
| Invalid | `0` = no depth return |
| Registration | Aligned to RGB (Section 4) |

If the camera's `depth_scale` is not 0.001 m, extraction converts values to
millimetres. Depth from a lossy encoding is not allowed.

## 6. Session metadata (`session.json`)

`session.json` holds everything that is constant for a session, including all
calibration. Samples inherit it through `session_id`.

```json
{
  "schema_version": "1.0",
  "session_id": "20261006_e7-hallway_r03",
  "environment": "hallway",
  "location": "e7-hallway",
  "recorded_start_ns": 1791311400000000000,
  "recorded_end_ns": 1791311580000000000,
  "source": {
    "bag_path": "recordings/20261006_e7-hallway_r03",
    "storage": "mcap",
    "rgb_topic": "/camera/camera/color/image_raw",
    "rgb_source_encoding": "rgb8",
    "rgb_info_topic": "/camera/camera/color/camera_info",
    "depth_topic": "/camera/camera/aligned_depth_to_color/image_raw",
    "depth_info_topic": "/camera/camera/aligned_depth_to_color/camera_info"
  },
  "camera": {
    "model": "Intel RealSense D435i",
    "serial": "123456789012",
    "firmware": "5.16.0.1"
  },
  "image": {
    "width": 640,
    "height": 480
  },
  "depth": {
    "units": "mm",
    "invalid_value": 0,
    "source_depth_scale_m": 0.001,
    "aligned_to_rgb": true,
    "aligned_by": "realsense_driver"
  },
  "calibration": {
    "source": "camera_info",
    "rgb_intrinsics": {
      "fx": 615.0,
      "fy": 615.0,
      "cx": 320.0,
      "cy": 240.0
    },
    "distortion_model": "plumb_bob",
    "distortion_coeffs": [0.0, 0.0, 0.0, 0.0, 0.0],
    "depth_to_rgb": {
      "rotation": [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
      "translation_m": [0.015, 0.0, 0.0]
    },
    "rgb_to_base_link": null
  },
  "pairing": {
    "max_dt_ns": 10000000,
    "rgb_frames": 5400,
    "paired": 5391,
    "rejected": 9
  },
  "extraction": {
    "tool": "extract-pairs@0.1.0",
    "date": "2026-10-07T09:00:00Z",
    "stride": 1
  }
}
```

| Field | Values / meaning |
| --- | --- |
| `environment` | `hallway` or `tube_track`. Selects the segmentation rule set (Section 9). |
| `source.rgb_source_encoding` | ROS `encoding` of the colour topic, or the compression format (`jpeg`, `png`) if compressed. |
| `depth.aligned_by` | `realsense_driver` or `extraction`. |
| `calibration.source` | `camera_info`, `factory`, or `none`. With `none`, every calibration field is `null`. |
| `calibration.rgb_intrinsics` | Intrinsics of the RGB image as stored on disk. These are also the intrinsics of the aligned depth. |
| `calibration.depth_to_rgb` | Row-major 3x3 rotation and translation from the depth sensor to the RGB sensor. `null` if unavailable. |
| `calibration.rgb_to_base_link` | Same structure, from the RGB optical frame to the vehicle `base_link`. `null` if unknown. |
| `extraction.stride` | Every Nth valid pair was kept (`1` = all). |

## 7. Sample metadata (`meta/<sample_id>.json`)

```json
{
  "schema_version": "1.0",
  "sample_id": "20261006_e7-hallway_r03_000412",
  "session_id": "20261006_e7-hallway_r03",
  "frame_index": 412,
  "rgb_timestamp_ns": 1791311413733412000,
  "depth_timestamp_ns": 1791311413731205000,
  "pair_dt_ns": -2207000,
  "image": {
    "width": 640,
    "height": 480
  },
  "depth": {
    "units": "mm",
    "invalid_value": 0,
    "valid_fraction": 0.93
  },
  "annotations": {
    "detection": { "...": "see Section 10" },
    "segmentation": { "...": "see Section 10" }
  }
}
```

| Field | Meaning |
| --- | --- |
| `frame_index` | Integer form of the `<frame>` part of the sample ID. |
| `pair_dt_ns` | `depth_timestamp_ns - rgb_timestamp_ns`. Its absolute value is at most `10_000_000`. |
| `image` | Width and height of both the RGB and depth files. Must equal `session.json` `image`. |
| `depth.valid_fraction` | Fraction of depth pixels that are not `invalid_value`, in `[0, 1]`. |
| `annotations` | One provenance record per annotation type (Section 10). |

Calibration is not repeated per sample. Join on `session_id` to read it from
`session.json`.

## 8. Detection annotations

### 8.1 Class

There is one class.

| `class_id` | Name | Includes |
| --- | --- | --- |
| `0` | `car` | RC test cars and open-top F1Tenth/RoboRacer vehicles |

`car` includes:

- RC test cars at roughly 1/10 scale, with or without a body shell.
- Open-top F1Tenth/RoboRacer vehicles: exposed chassis with a platform deck,
  lidar, compute, and wiring.
- Such vehicles in any state: moving, parked, carried, upside down, or on a
  stand.

`car` excludes:

- The ego vehicle (any part of the recording car visible in frame).
- Images of cars: posters, screens, and reflections in floors, walls, or
  windows.
- Full-size vehicles, other robot platforms, carts, and scooters.

Representative examples are in `docs/examples/cars/` (Section 13).

An optional per-box `subtype` (`rc_car` or `f1tenth`) in `tracks.json` is for
analysis only. It is not a training class.

### 8.2 Bounding-box rules

| Case | Rule |
| --- | --- |
| Extent | **Amodal.** The box covers the full estimated extent of the car, including parts hidden behind other objects. |
| Occlusion | Estimate the hidden extent from the visible parts and the known size of the car. Set `occluded: true` when less than about 50% of the car is visible because something is in front of it. |
| Partial visibility | Box every car that a reviewer can identify as a car. There is no minimum visible fraction. |
| Fully hidden | Do not box a car with no visible pixels, even if tracking says it is there. |
| Image boundary | Clip the amodal box to the image. Set `truncated: true` and record the unclipped amodal box as `unclipped_xyxy_px` in `tracks.json`. |
| Size | There is no minimum box size. |
| Attached equipment, inside the box | Chassis, body shell, wheels, tyres, lidar, compute stack, platform deck, camera and sensor mounts, bumpers, rigidly mounted batteries. |
| Attached equipment, outside the box | Loose or hanging cables, antennas, flags, hanging tape, tethers. |
| People | A hand or arm holding a car is not part of the box. |
| Tightness | Box edges touch the outermost included part (for occluded parts, its estimated position). No padding. |

### 8.3 Label file (`labels/<sample_id>.txt`)

Ultralytics YOLO detection format: one line per car.

```
<class_id> <cx> <cy> <w> <h>
```

- `cx cy w h` are the clipped box centre, width, and height, normalised to
  `[0, 1]` by image width and height, with six decimal places.
- Fields are separated by a single space, with one line per box and a newline
  at the end of the file.
- **Line order is significant.** `tracks.json` refers to boxes by zero-based line
  index. Editing tools must keep `tracks.json` in sync when they add, remove, or
  reorder lines.
- An empty file means the image has no cars.

```
0 0.512500 0.618750 0.231250 0.183333
0 0.075000 0.591667 0.150000 0.141667
```

### 8.4 Track sidecar (`tracks.json`)

One file per session. It holds track IDs and the attributes for each box.

```json
{
  "schema_version": "1.0",
  "session_id": "20261006_e7-hallway_r03",
  "tracks": {
    "1": { "subtype": "f1tenth", "note": "white deck, blue lidar" },
    "2": { "subtype": "rc_car", "note": null }
  },
  "boxes": {
    "20261006_e7-hallway_r03_000412": [
      { "line": 0, "track_id": 1, "occluded": false, "truncated": false, "unclipped_xyxy_px": null },
      { "line": 1, "track_id": 2, "occluded": false, "truncated": true, "unclipped_xyxy_px": [-42.0, 250.0, 96.0, 318.0] }
    ]
  }
}
```

| Field | Meaning |
| --- | --- |
| `tracks.<id>` | One entry per physical car in the session. `subtype` is `rc_car`, `f1tenth`, or `null`. |
| `boxes.<sample_id>` | One entry per line of the sample's label file, in the same order. |
| `line` | Zero-based line index in `labels/<sample_id>.txt`. |
| `track_id` | Track the box belongs to. |
| `occluded` | Section 8.2. |
| `truncated` | `true` if the amodal box crosses the image boundary. |
| `unclipped_xyxy_px` | `[x1, y1, x2, y2]` of the amodal box before clipping. Values may fall outside the image. `null` unless `truncated`. |

Track ID rules:

- The same physical car keeps the same `track_id` for the whole session,
  including after it leaves the frame and comes back, as long as it can be
  identified.
- If a returning car cannot be identified with confidence, give it a new
  `track_id`.
- A `track_id` is never reused for a different car within a session.
- Within one sample, every box has a different `track_id`.

## 9. Segmentation annotations

### 9.1 Mask file (`masks/<sample_id>.png`)

| Property | Value |
| --- | --- |
| Format | PNG, 8-bit, 1 channel (greyscale, mode `L`). Not palette or RGB. |
| Size | Same width and height as the sample's RGB image |
| `0` | Not drivable |
| `1` | Drivable |
| `255` | Ignore. Excluded from loss and metrics. |

No other values are allowed. Masks look black in ordinary image viewers; use a
visualisation tool to inspect them.

### 9.2 Drivable (`1`)

| Environment | Drivable surface |
| --- | --- |
| `tube_track` | Floor inside the track boundary (between the boundary tubes) that no obstacle covers. |
| `hallway` | Any flat floor the car can physically drive on that no obstacle covers. |

In both environments:

- Floor markings, tape lines, shadows, thin mats, floor joins, and threshold
  strips the car can drive over are drivable.
- A reflection on a glossy floor is still floor. It is drivable unless the
  floor boundary cannot be judged (Section 9.4).
- Floor under furniture or other overhanging objects is drivable only if there is
  clearly enough clearance for the car. Otherwise it is not drivable. If you
  cannot tell, mark it ignore.

### 9.3 Not drivable (`0`)

- Track boundary tubes, including the floor they rest on.
- On `tube_track`, all floor outside the track boundary.
- Walls, baseboards, doors, pillars, furniture, and other fixed structures.
- Cars on the floor (the full visible body), people, bags, boxes, debris,
  cables, and any object the car would hit, however small.
- Stairs, steps, and surfaces the car cannot drive onto.
- Everything that is not floor (walls, ceiling, windows).

### 9.4 Ignore (`255`)

| Region | Rule |
| --- | --- |
| Ego vehicle | Any part of the recording car visible in frame. |
| Far floor | Floor, and anything resting on the floor, more than 5 m away by aligned depth (`> 5000` mm). Where depth is invalid, judge the 5 m limit visually from the surrounding valid depth. Walls and other clearly non-floor surfaces beyond 5 m stay `0`. |
| Ambiguous floor | Floor that is too dark, blurred, or distant to judge as drivable or not. |
| Reflections and glare | Specular regions where the drivable boundary cannot be judged. |
| Invalid depth | Pixels with depth `0`, **only** where the RGB is also unclear. Depth holes over clearly visible floor or obstacles are labelled from the RGB as usual. |

## 10. Annotation provenance

Detection and segmentation each have their own provenance record in
`meta/<sample_id>.json` under `annotations.detection` and
`annotations.segmentation`.

### 10.1 Status values

| Status | Meaning |
| --- | --- |
| `none` | Not produced yet. No label or mask file exists. |
| `generated` | Produced by a tool. No member has checked it. |
| `reviewed` | A member checked a generated annotation and accepted it unchanged. |
| `corrected` | A member created the annotation by hand, or edited it. |
| `excluded` | Must not be used for training or evaluation. Requires an exclusion reason. |

### 10.2 Record format

```json
{
  "status": "corrected",
  "generator": "yolo-autolabel@0.2.0",
  "updated": "2026-10-08T10:12:00Z",
  "exclusion": null,
  "history": [
    { "status": "generated", "by": "yolo-autolabel@0.2.0", "date": "2026-10-07T14:00:00Z", "note": null },
    { "status": "corrected", "by": "mrahman", "date": "2026-10-08T10:12:00Z", "note": "added second car at left edge" }
  ]
}
```

| Field | Meaning |
| --- | --- |
| `status` | Current status. Always equals the status of the last `history` entry. |
| `generator` | Tool ID that produced the first version, or `null` if it was made by hand. |
| `updated` | Time of the last `history` entry. |
| `exclusion` | `null` unless `status` is `excluded`. Then `{ "reason": <reason>, "note": <string or null> }`. |
| `history` | Every status change, oldest first. `by` is a member ID or a tool ID. Never edited or truncated. |

A record with `status: none` has an empty `history`, and `generator`, `updated`,
and `exclusion` set to `null`.

Exclusion reasons:

| Reason | Use when |
| --- | --- |
| `pairing_failed` | The pair passed the timestamp check but the depth frame is unusable or does not match the RGB (frozen stream, wrong frame, misregistration). |
| `motion_blur` | The image is too blurred to annotate reliably. |
| `corrupt` | A file is unreadable, truncated, or garbled. |
| `duplicate` | The frame is a duplicate or near-duplicate of another sample. |
| `other` | Any other reason. `note` is required. |

If a problem affects the whole sample (e.g. `corrupt`), set both annotation types
to `excluded`.

### 10.3 Rules

- Any one member may move an annotation to `reviewed` or `corrected`, including
  the member who made it. The member ID and date are recorded in `history`.
- Allowed transitions:
  - `none` → `generated`, `corrected`, or `excluded`
  - `generated` → `reviewed`, `corrected`, or `excluded`
  - `reviewed` → `corrected` or `excluded`
  - `corrected` → `corrected` (further edit) or `excluded`
  - `excluded` → the status it had before exclusion (restore, with a `note`)
- Re-running a generator overwrites only annotations whose status is
  `generated`. It never overwrites `reviewed`, `corrected`, or `excluded`.
- A label or mask file exists if the status is `generated`, `reviewed`, or
  `corrected`, and does not exist if the status is `none`. Files for `excluded`
  annotations may stay on disk; consumers must check the status before using a
  file.
- Training configurations state which statuses they use. Evaluation uses only
  `reviewed` and `corrected`.

## 11. Predictions

Model outputs are written under `src/data/predictions/<run_id>/`. A `run_id` is
unique, lowercase, and uses hyphens within fields and underscores between them,
e.g. `20261012_yolo11n-car_v1`. Predictions are never written into
`datasets/`.

### 11.1 Run metadata (`run.json`)

```json
{
  "schema_version": "1.0",
  "run_id": "20261012_yolo11n-car_v1",
  "task": "detection",
  "model": "yolo11n-car",
  "weights": "runs/detect/car_v1/weights/best.pt",
  "weights_sha256": "3f5a...",
  "tracker": "bytetrack",
  "position_method": "median_valid_depth_in_box_center_region",
  "conf_threshold": 0.25,
  "created": "2026-10-12T16:40:00Z",
  "sessions": ["20261006_e7-hallway_r03"]
}
```

| Field | Meaning |
| --- | --- |
| `task` | `detection` or `segmentation`. |
| `tracker` | Tracker name, or `null` if tracking is off. |
| `position_method` | Name of the method used to compute `position_m`, or `null` if positions are not produced. |

### 11.2 Detection and tracking (`detections.jsonl`)

One JSON object per line, one line for every processed sample (including samples
with no detections), ordered by `rgb_timestamp_ns`.

```json
{"sample_id": "20261006_e7-hallway_r03_000412", "rgb_timestamp_ns": 1791311413733412000, "detections": [{"track_id": 7, "class_id": 0, "bbox_xywhn": [0.5121, 0.6190, 0.2298, 0.1840], "conf": 0.94, "position_m": [0.21, 0.08, 2.47]}]}
```

| Field | Meaning |
| --- | --- |
| `track_id` | Tracker-assigned ID, unique within this run and session. `null` if tracking is off. Unrelated to ground-truth `track_id`s. |
| `class_id` | Always `0`. |
| `bbox_xywhn` | Box centre, width, and height, normalised as in Section 8.3. |
| `conf` | Detection confidence in `[0, 1]`. |
| `position_m` | `[x, y, z]` of the vehicle in the camera frame (Section 1), in metres. `null` if there is no valid depth for the box. |

### 11.3 Segmentation

| File | Format |
| --- | --- |
| `masks/<sample_id>.png` | Same encoding as Section 9.1, but only `0` and `1`. Predictions never contain `255`. |
| `probs/<sample_id>.png` (optional) | 8-bit, 1 channel, value = `round(255 * P(drivable))`. Here `255` means probability 1, not ignore. |

## 12. Validation rules

A dataset session is valid when all of the following hold.

Identifiers and files:

- The session ID and every sample ID match the regexes in Section 2.
- Every sample has `rgb/`, `depth/`, and `meta/` files with the same sample ID.
- No file in the session directory is named with a sample ID that has no `meta/`
  file.

Pairing and images:

- `abs(pair_dt_ns) <= session.pairing.max_dt_ns <= 10_000_000`, and
  `pair_dt_ns == depth_timestamp_ns - rgb_timestamp_ns`.
- RGB is 8-bit 3-channel, depth is 16-bit 1-channel, and both equal
  `meta.image` and `session.image` in size.

Annotation files:

- Label and mask files exist exactly when the provenance rules in Section 10.3
  say they must.
- Every label line has five fields, `class_id == 0`, and coordinates in
  `[0, 1]`.
- Every sample with a label file has a `tracks.json` entry with one item per
  line, `line` values `0..n-1` in order, and different `track_id`s that all
  exist in `tracks`.
- If `truncated` is true, `unclipped_xyxy_px` is present; otherwise it is `null`.
- Mask values are only `0`, `1`, and `255`.

Provenance:

- `status` equals the last `history` status, and every transition in
  `history` is allowed.
- `exclusion` is set exactly when `status` is `excluded`, and `note` is non-null
  when the reason is `other`.

## 13. Examples

`docs/examples/` holds small paired examples that follow this standard:

| Path | Shows |
| --- | --- |
| `20261006_e7-hallway_r03/` | Hallway sample: one fully visible car, one car truncated at the image edge. Detection `corrected`, segmentation `generated`. |
| `20261010_tube-track_r01/` | Tube-track sample: one car occluded behind another (amodal box). Detection `reviewed`, segmentation `corrected`. Plus one sample with both types `excluded`. |
| `predictions/20261012_yolo11n-car_v1/` | Detection run metadata and a `detections.jsonl` line. |
| `cars/` | Representative images of the `car` class. |

See `docs/examples/README.md` for the image files still to be added.
