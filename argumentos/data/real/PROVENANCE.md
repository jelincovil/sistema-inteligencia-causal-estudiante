# LaLonde / MatchIt / Rdatasets provenance

## Retrieved object

- Local raw artifact: `data/real/lalonde.csv` (615 CSV lines including the header).
- Retrieved at: `2026-11-22T02:22:02Z` (machine UTC clock).
- Pinned raw URL: <https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/1dcc2bf5f955cc1224a3e1307256e1fe86b68dae/csv/MatchIt/lalonde.csv>.
- Resolved `master` commit at retrieval: `1dcc2bf5f955cc1224a3e1307256e1fe86b68dae`, obtained from `https://api.github.com/repos/vincentarelbundock/Rdatasets/commits/master`.
- Exact size: **27,509 bytes**.
- SHA-256: `a49703ca0233ba0a27fa9cda959a38a07f6825def0f7743cf2380ce4e57dd3ef`.
- The first-line header and NSW row identifiers are preserved. No values, types, labels, or row ordering are edited.

The unmodified CSV is pinned for local reproducibility. It is not redistributed in this public repository snapshot because upstream data-value rights remain unverified. Inclusion locally is not a new license grant; before redistribution, verify rights with the upstream data providers.

## Documentation and intellectual lineage

- Source documentation: <https://vincentarelbundock.github.io/Rdatasets/doc/MatchIt/lalonde.html>, also pinned at <https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/1dcc2bf5f955cc1224a3e1307256e1fe86b68dae/doc/MatchIt/lalonde.html>.
- It describes 614 observations: 185 treated people from the National Supported Work Demonstration (NSW) and 429 comparison observations from the Panel Study of Income Dynamics (PSID), as analysed by Dehejia and Wahba (1999), following LaLonde (1986).
- `treat` is treatment, `re78` is 1978 earnings (the outcome), and age, education, race, married, nodegree, `re74`, and `re75` are documented pre-treatment covariates. Earnings are documented as US dollars for their respective years. Dollar amounts across years are not inflation-adjusted by this project.
- The primary citations are LaLonde (1986), *American Economic Review* 76, 604–620, and Dehejia and Wahba (1999), *Journal of the American Statistical Association* 94, 1053–1062. Heckman, LaLonde & Smith (1999), DOI `10.1016/S1573-4463(99)03012-6`, is added as methodological context. These works document design and interpretation; the byte pin here documents this exact executable input.
- Bibliographic curation consulted OpenAlex and Semantic Scholar without changing the byte pin. OpenAlex: LaLonde `W2150118316` (exact-title record currently dated 1984 under the 1986 AER title), Dehejia & Wahba JASA `W3122948292` / alternate `W2891753394` for DOI `10.1080/01621459.1999.10473858`, and Heckman et al. `W1530306231`. Semantic Scholar: LaLonde `61572150188f35378fa208a158d2dbe0817647b8`; Chernozhukov et al. DML `f75b70c9d7078724b592ec3e21de705e7b6ff73f`. Treat these as lookup metadata, not evidence that the cited studies verify or license this CSV.

## License/status: explicitly unresolved for the data values

The Rdatasets `README.md` at retrieval licenses its **code** under GPL-3 and states that its author believes the copied R documentation is GPL. Crucially, it also states that a good-faith effort did not find a definitive answer for the license of the actual data values, while expressing an understanding that they are free to redistribute. MatchIt's current package `DESCRIPTION` states GPL (>=2) for the package. Neither statement is treated here as a reliable, dataset-specific license for this CSV. This project therefore records `data_value_license: unresolved_upstream`, not “public domain” and not GPL by assumption.

Sources read directly with `curl` on 2026-11-22 UTC:

- <https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/master/README.md>
- <https://raw.githubusercontent.com/kosukeimai/MatchIt/master/DESCRIPTION>
- <https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/master/datasets.csv>

A later direct-source recheck on 2026-11-22 UTC saved the pinned raw CSV and response headers under ignored `build/reverification/upstream/`. The response was HTTP 200 with response date `Sun, 22 Nov 2026 02:51:45 GMT` and `content-length: 27509`; `cmp` confirmed byte identity with the bundled CSV, and both SHA-256 values matched the pin above. The documentation file and package metadata in that same ignored directory were read directly. These observations record the recheck, not a trusted publication timestamp or a new license grant.

## Identification boundary

This CSV combines NSW treated observations with a nonexperimental PSID comparison group. It is **not** relabelled as the NSW randomized controlled sample, and it is not Jobs/IHDP/synthetic data. The `NSW…`/`PSID…` identifiers are source row labels, not evidence of repeated panel-membership tracking in this artifact. No observation date/epoch is supplied, so temporal split testing is unavailable. Measured baseline covariates do not establish unconfoundedness; selection into NSW and the comparison construction remain substantive threats. The executable adjusted estimate is therefore conditional and exploratory, never proof of the NSW program's causal effect in a broader population.
