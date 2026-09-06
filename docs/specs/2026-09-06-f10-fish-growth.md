# F10 — 鱼随时间成长

> Implements: GitHub issue [#10](https://github.com/hnlisf/yopet/issues/10)

## Purpose

Fish grow from fry to juvenile to adult as a calm expression of time passing.
Time is always the primary trigger: species defaults are seven days to juvenile
and 21 days to adult. Meals provide a small, optional acceleration and never
make growth a task the player must maintain.

## Persistence

`growth_logs` stores the fish, source stage, destination stage, trigger time
and one of two reasons: `time` or `feeding_acceleration`. Per-species fields
configure the faster targets (five and 15 days by default). When at least one
meal exists, every two feeding logs contribute one effective day; time still
wins whenever its normal threshold is met.

`sync_tank_growth` is an owner-checked SECURITY DEFINER RPC invoked when the
tank opens. It promotes every due stage in sequence, so a long absence creates
both `fry → juvenile` and `juvenile → adult` records instead of skipping state.
No cron, polling process or punitive condition is added.

## Visual system

Every species has `fry.png`, `juvenile.png` and `adult.png` resources. The
sprite widget switches by stage and uses exact 1.5x steps: fry `0.44`, juvenile
`0.66`, adult `0.99`. The goldfish juvenile resource is a new transparent
watercolor growth variant generated from the approved base-fish art; other
species retain their approved silhouette per stage until bespoke artwork is
commissioned.

The action sheet exposes the current Chinese stage label alongside satiety.

## Verification

- SQL validation sets a fish to eight days old and confirms it becomes juvenile;
  it also confirms a 22-day fish produces the two sequential growth logs.
- Dart tests verify Chinese stage labels, stage file selection and both 1.5x
  visual ratios.
