# Examples

Small paired examples of the formats in [`../data-standard.md`](../data-standard.md).
The directory structure matches `src/data/datasets/` and `src/data/predictions/`.

| Path | Shows |
| --- | --- |
| [`20261006_e7-hallway_r03/`](20261006_e7-hallway_r03/) | Hallway sample `000412`: one fully visible F1Tenth car (track 1) and one RC car truncated at the left edge (track 2, with `unclipped_xyxy_px`). Detection `corrected`, segmentation `generated`. |
| [`20261010_tube-track_r01/`](20261010_tube-track_r01/) | Tube-track sample `000057`: one car occluded behind another (track 2, amodal box, `occluded: true`). Detection `reviewed`, segmentation `corrected` (hand-made). Sample `000058`: both annotation types `excluded` for `motion_blur`. |
| [`predictions/20261012_yolo11n-car_v1/`](predictions/20261012_yolo11n-car_v1/) | Detection run metadata and one `detections.jsonl` line. |
| `cars/` | Representative images of the `car` class. |

## Files to add

The JSON and label files are complete. The images below still need to be added
from real recordings. Once the real frames are in, update the box coordinates in
`labels/`, `tracks.json`, and `detections.jsonl`, and the timestamps and
calibration in `meta/` and `session.json`, to match them.

Paired samples (RGB 8-bit PNG, depth 16-bit PNG in mm, mask 8-bit PNG with
values 0/1/255, all the same size):

- [ ] `20261006_e7-hallway_r03/rgb/20261006_e7-hallway_r03_000412.png`
- [ ] `20261006_e7-hallway_r03/depth/20261006_e7-hallway_r03_000412.png`
- [ ] `20261006_e7-hallway_r03/masks/20261006_e7-hallway_r03_000412.png`
- [ ] `20261010_tube-track_r01/rgb/20261010_tube-track_r01_000057.png`
- [ ] `20261010_tube-track_r01/depth/20261010_tube-track_r01_000057.png`
- [ ] `20261010_tube-track_r01/masks/20261010_tube-track_r01_000057.png`
- [ ] `20261010_tube-track_r01/rgb/20261010_tube-track_r01_000058.png` (a blurred frame)
- [ ] `20261010_tube-track_r01/depth/20261010_tube-track_r01_000058.png`

Visualisations (`vis/` exists only in these examples, not in real datasets), so members can check the rules by eye (box outlines with track
IDs; mask overlay with drivable in green, not drivable left clear, ignore in grey):

- [ ] `20261006_e7-hallway_r03/vis/20261006_e7-hallway_r03_000412_boxes.png`
- [ ] `20261006_e7-hallway_r03/vis/20261006_e7-hallway_r03_000412_mask.png`
- [ ] `20261010_tube-track_r01/vis/20261010_tube-track_r01_000057_boxes.png`
- [ ] `20261010_tube-track_r01/vis/20261010_tube-track_r01_000057_mask.png`

Representative `car` examples, each a frame or crop with the correct box drawn:

- [ ] `cars/rc_car_shell.png`: RC test car with a body shell
- [ ] `cars/rc_car_no_shell.png`: RC test car without a body shell
- [ ] `cars/f1tenth_front.png`: open-top F1Tenth vehicle from the front
- [ ] `cars/f1tenth_side.png`: open-top F1Tenth vehicle from the side, with the
  lidar and compute stack inside the box and loose cables and antenna outside it
- [ ] `cars/not_a_car_reflection.png`: car reflection on a glossy floor (not boxed)
