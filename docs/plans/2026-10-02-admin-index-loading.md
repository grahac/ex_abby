# Smallest viable version

Render the ExAbby index without querying reports during the initial HTTP mount.
Use LiveView's native async loading to fetch experiment metadata and calculate
reports only for the selected Running, Archived, or All tab. Keep the existing
statistical calculations, search, links, and recently archived list.

Running and archived totals remain global. Label the significant-results count
as applying to the selected tab, so archived trial summaries are unnecessary
when viewing Running. Show loading and failure states instead of an empty-results
message while data is unavailable.

Verification: exercise the actual LiveView lifecycle without a listening server
or database, including the initial render, selected report queries, search, and
tab changes; run warnings-as-errors compilation, formatting, and library tests.

No batching, report cache, schema changes, publication, or deployment in this unit.

Completed locally: warnings-as-errors compilation and formatting passed; all 127
library tests passed, including zero-query HTTP rendering, selected-tab summaries,
archive metadata, search, delayed tab responses, and the failure state. The test
endpoint has `server: false`; no database or listening development server was used.
