# Visualization

## Choose by comparison type, not by taste
| The question | Chart |
| --- | --- |
| Ranking between categories | horizontal bar, sorted by value |
| Change over time | line (many points) or vertical bar (few periods) |
| Part of a whole | stacked bar or a labelled share list — a pie only for 2–3 slices |
| Contribution to a change | waterfall |
| Relationship between two measures | scatter |
| Spread of one measure | histogram / box |
| Stage drop-off | funnel |
| Two dimensions, one measure | heatmap |
| Single decisive number | big-number KPI tile with its delta and period |

Default to a sorted bar chart when unsure. Never use a dual y-axis, a 3D effect, or a truncated y-axis on a bar chart — bars encode length, so they start at zero.

## Insight-led headline
Every chart carries a title that states the finding, not the contents: "Drop-off concentrates at the survey stage (‑42%)", not "Funnel by stage". One proposition per chart. The subtitle carries population, range and source. Both come from i18n keys with interpolated values.

## Recharts conventions
- `ResponsiveContainer` with a fixed pixel height on the wrapper; no hardcoded widths.
- Colors only from design tokens (`var(--chart-1)`…`--chart-5`, `--muted-foreground` for axes/grid). Never literal hex or `text-white`-style utilities.
- One accent color carries the message; everything else is neutral grey. Series colors are stable across renders and charts — map by key, not by array index.
- Axis, legend, tooltip formatters: locale-aware number/date formatting (`Intl.NumberFormat`, `date-fns`), percentages with an explicit precision, units in the axis label rather than on every tick.
- Rotate or truncate long category labels — never shrink the font below readable size; if labels do not fit, switch to a horizontal bar chart.
- Grid: horizontal lines only, muted. Drop the legend when there is a single series.
- Animate on mount only; re-render animation on every filter change reads as flicker.

## Adaptive layout
Follow the project's device split: on mobile serve a distinct structure (fewer series, horizontal bars, scrollable table fallback, drawer for details), not a squeezed desktop chart. Tooltips are hover-only — on touch, the value must also be reachable by tap or be printed on the chart.

## States
Loading = skeleton of the chart's footprint (no layout jump). Empty = short explanation plus the action that would produce data. Error = toast or inline message with retry; never a blank canvas or a white screen.

## Accessibility & export
Do not encode meaning by color alone — add labels, patterns or direct annotation. Every chart has an accessible name. Where the user needs the numbers, offer the underlying table or a CSV export of exactly the rows shown.
