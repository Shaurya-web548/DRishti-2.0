# Project report generator

Builds `out/DRishti_Project_Report.docx` and its PDF from measured data, so the
report never carries a hand-typed number.

| File | What it holds |
|------|---------------|
| `collectReportData.m` | Runs every capacity scenario the report quotes; writes `report_data.json` |
| `measurements.json` | Timings and test results measured outside MATLAB, with where they came from |
| `figures/` | Screenshots of the running web app |
| `build_report.js` | The report text and layout |
| `finish_report.ps1` | Word step: fills the contents list and exports the PDF |

The team comes from `app/python/content/team.json`. Empty fields show up as
yellow-highlighted blanks, so fill that file in and rebuild.

```powershell
cd tools\report
npm install                 # first time only
node build_report.js
.\finish_report.ps1
```

Re-run `collectReportData` in MATLAB first if the capacity model changed.
