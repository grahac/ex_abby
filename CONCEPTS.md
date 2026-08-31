# Concepts

Shared domain vocabulary for this project — entities, named processes, and
status concepts with project-specific meaning. Seeded with core domain
vocabulary, then accretes as ce-compound and ce-compound-refresh process
learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Experiment results

### Experiment

A named allocation and measurement container that groups variations and the
success outcomes used to compare them.

### Variation

One allocation arm within an Experiment, representing either the baseline or a
treatment whose outcomes are measured independently.

### Variation weight

A non-negative relative allocation value that determines how likely a Variation
is to be selected compared with the other Variations in the same Experiment.

### Trial

A participant's persistent assignment to one Variation within an Experiment,
carrying that participant's eligibility and measured success outcomes.

### Control variation

The baseline Variation against which every treatment is compared when ExAbby
reports control-relative significance.

### Success metric

A binary per-trial conversion outcome used to compare Variations within an
Experiment; repeated success events on the same trial still count as one
converter for significance.

### Correction family

The set of treatment-by-metric comparisons whose p-values are adjusted together
when any member can identify a winner.
