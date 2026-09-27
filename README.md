# DRishti 2.0 — Diabetic Retinopathy Screening

> **Version 2.0.** Version 1 lives at [github.com/Shaurya-web548/DRishti](https://github.com/Shaurya-web548/DRishti).
>
> New in 2.0:
> - A five-page web app: animated landing page, screening tool, scroll-driven
>   "How it works", the **Simulink capacity model** run live in MATLAB, and an
>   About page with the team.
> - Runs on **base MATLAB**: a pure-MATLAB layer replaces the Image Processing
>   Toolbox functions the pipeline needs, and the Simulink block diagram is solved
>   in base MATLAB when Simulink is not installed.
> - Four integration bugs fixed so a scan runs end to end, and 33 MB less output per scan.
> - Patient age validated (0–120) in the browser and on the server; results route
>   hardened against path traversal.
> - Full APTOS 2019 used for training by default; Messidor-2 and IDRiD held out.
> - Tests: 56 pytest tests and 61 image-processing checks; a regenerable project
>   report in `tools/report/`.

An end-to-end diabetic retinopathy (DR) screening pipeline: a fundus photograph
goes in, and an ICDR grade (0–4), a referral decision, an annotated lesion
overlay, a Grad-CAM attention map and a patient-facing PDF report come out.

Built for screening settings where an ophthalmologist isn't down the hall — a
technician captures a fundus image, the tool says whether this person needs to
see a specialist, and how soon.

**Image analysis and grading run in MATLAB. A Flask app wraps them for the browser.**

> ⚠️ **Not a medical device.** This is a research and educational project. Its
> output is a screening signal, not a diagnosis, and it has not been clinically
> validated. Always consult a qualified eye care professional.

---

## What it actually does

```
fundus image
     |
     v
+-------------------------------------------------------------+
| 1. QUALITY GATE       assessImageQuality.m                  |
|    Hough-circle field of view - Laplacian-variance blur -   |
|    histogram exposure -> pass / enhanced (CLAHE) / reject   |
+-------------------------------------------------------------+
     |  (rejected images stop here - no grade is guessed)
     v
+-------------------------------------------------------------+
| 2. SEGMENTATION       segmentRetina.m                       |
|    Optic disc - fovea - vessels (matched filter) -          |
|    microaneurysms - exudates - haemorrhages - NV proxy      |
+-------------------------------------------------------------+
     |
     v
+--------------------------+   +------------------------------+
| 3a. RULE GRADING         |   | 3b. CNN GRADING              |
|  gradeByRules.m          |   |  trainDRClassifier.m         |
|  ICDR scale + 4-2-1 rule |   |  predictDRGrade.m            |
|  (fully inspectable)     |   |  calibrateConfidence.m       |
+--------------------------+   +------------------------------+
     |                                    |
     +-----------> combineGrades.m <------+
                   agree    -> grade
                   disagree -> flag for human review
     |
     v
+-------------------------------------------------------------+
| 4. EXPLANATION        gradCAMHeatmap - drawLesionOverlay -   |
|                       explainGrading - compileReportData     |
+-------------------------------------------------------------+
     |
     v
+-------------------------------------------------------------+
| 5. DELIVERY           Flask UI + PDF report                 |
+-------------------------------------------------------------+
```

### Two runtime modes, chosen automatically

| Mode | When | What you get |
|------|------|--------------|
| `real_full` | A trained `drClassifier.mat` loads successfully | CNN + rules combined, Grad-CAM, calibrated confidence, lesion overlay |
| `real_no_cnn` | Model missing, unreadable, or untrained | Rule-based ICDR grade + lesion overlay. No Grad-CAM, no confidence score |

The fallback is automatic. Nothing crashes and no flag needs flipping when the
model isn't there — the pipeline degrades to the rule-based path and says so in
`report.mode`.

---

## Design decisions worth calling out

**Segmentation is classical, not learned.** `segmentRetina.m` uses matched
filters, top-hat transforms and background subtraction rather than a trained
segmentation network. Every decision it makes is inspectable — the orientation,
the scale, the threshold — which matters more than raw accuracy when a clinician
asks *why* a pixel was called a haemorrhage. All thresholds are expressed as
fractions of the field-of-view radius, so the same settings transfer across
image sizes and cameras. An optional U-Net path (`dlSegmentVessels.m`) can be
dropped in for vessels; it never throws, and falls back to the classical result
if the model is missing.

**Confidence is calibrated, not raw softmax.** Neural networks are
systematically overconfident. `calibrateConfidence.m` fits Platt scaling on the
validation split so a reported "80%" means *this prediction is correct about 80%
of the time*, and it reports expected calibration error before and after.

**The referral threshold is tuned for sensitivity, not accuracy.** In screening,
a missed referable case costs far more than a false alarm.
`tuneReferableThreshold.m` picks the operating point with the best specificity
*among the cut-offs that hit 90% sensitivity*, rather than maximising overall
accuracy.

**CNN and rules must agree.** `combineGrades.m` returns `agree` only when both
paths give the same grade *and* the same referral decision. Otherwise it returns
`review` with `grade = NaN`, and marks the case referable if *either* method says
so — the safe default for screening.

**The LLM never grades.** Gemini writes the plain-language paragraphs in the PDF
report and nothing else. The grade is passed to it as a fixed input, and the
system prompt forbids re-deriving, questioning or contradicting it. If
`GEMINI_API_KEY` is absent or the call fails, a canned clinically-neutral
paragraph is used and the report still generates.

**Honest labelling of what's weak.** Neovascularization detection
(`segmentRetina.m`, section 6) is an experimental classical proxy that flags
vessel clusters that are both denser and more tortuous than the peripheral
baseline. It will also fire on dense normal arcades and poor crops. It is
documented as a soft flag, not a detector. Haemorrhage detection likewise
localises haemorrhages but does not sub-type them into dot / blot / flame.

---

## Repository layout

```
matlab/
  assessImageQuality.m         Module 1 - quality gate + CLAHE enhancement
  segmentRetina.m              Module 2 - all lesion/anatomy segmentation
  dlSegmentVessels.m           Module 2 - optional U-Net vessel path (never throws)
  gradeByRules.m               Module 3 - ICDR grading incl. the 4-2-1 rule
  trainDRClassifier.m          Module 3 - transfer-learning fine-tune
  predictDRGrade.m             Module 3 - inference
  calibrateConfidence.m        Module 3 - Platt scaling + reliability diagram
  tuneReferableThreshold.m     Module 3 - ROC / operating point selection
  combineGrades.m              Module 3 - CNN + rules consensus
  gradCAMHeatmap.m             Module 4 - Grad-CAM attention map
  drawLesionOverlay.m          Module 4 - colour-coded lesion overlay
  explainGrading.m             Module 4 - heatmap + overlay + calibrated confidence
  compileReportData.m          Module 4 - JSON + PNG export for the web layer
  sortIntoGradeFolders.m       Utility - build data/0..4 from a labels CSV
  runDRPipeline.m              Script  - end-to-end training/eval walkthrough
  runDRPipelineProduction.m    Module 5 - the script Flask actually calls
  demoExplainGrading.m         Script  - smoke test with synthetic data

matlab/compat/                 Pure-MATLAB stand-ins for the Image Processing
                               Toolbox functions, used only when it is missing

capacity-model/
  drishtiCapacityDES.m         Discrete-event simulation of a district programme
  buildDRishtiSimulinkModel.m  Builds the Simulink flow model
  drishtiFlowModel.m           Same block equations, solved in base MATLAB
  drishtiRunScenario.m         One what-if run: DES + flow model + cross-check
  drishtiRunScenarioJSON.m     JSON wrapper the web app calls

app/python/
  app.py                       Flask server: pages + /api/scan, /api/report, /api/simulate
  matlab_bridge.py             Singleton MATLAB Engine wrapper
  report_generator.py          Gemini prose + fpdf2 PDF layout
  validation.py                Input checks (patient age 0-120, scenario ranges)
  site_content.py              Loads content/team.json for the About page
  content/team.json            Team roster - edit this to update the About page
  templates/ static/           Landing, screening, how-it-works, Simulink, about
  tests/                       pytest suite (run: python -m pytest tests)

models/
  drClassifier.mat             Demo checkpoint (see "About the checkpoint")

docs/
  index.html                   Project page (GitHub Pages)
```

---

## Requirements

**MATLAB** R2021a or newer (Grad-CAM needs R2021a+; `trainnet` needs R2024a+), with:

- Image Processing Toolbox — *recommended*. Without it the pipeline falls back
  to `matlab/compat/`, a pure-MATLAB implementation of the ~30 toolbox
  functions the screening path uses, so base MATLAB alone is enough to run a
  scan. See [matlab/compat/README.md](matlab/compat/README.md)
- Deep Learning Toolbox — required for the CNN path. Without it every scan runs
  in `real_no_cnn` mode: rule-based grading and the lesion overlay, but no
  Grad-CAM and no confidence score
- Statistics and Machine Learning Toolbox — for `fitglm` / `perfcurve`
- Computer Vision Toolbox — optional; without it the labelled overlay silently
  drops its text annotations rather than failing

**Python** 3.9+ with `flask`, `fpdf2`, `google-generativeai`, `Pillow`, `numpy`,
plus the MATLAB Engine for Python.

---

## Setup

### 1. MATLAB Engine for Python (one time)

```bash
cd "C:\Program Files\MATLAB\R2026a\extern\engines\python"
python -m pip install .
```

Run this from the same environment Flask will use.

### 2. Python dependencies

```bash
cd app/python
python -m pip install -r requirements.txt
```

### 3. Environment variables

Copy `.env.example` and fill it in, or export directly:

```bash
set MATLAB_SRC_DIR=C:\path\to\drishti\matlab
set DR_MODEL_PATH=C:\path\to\drishti\models\drClassifier.mat
set GEMINI_API_KEY=your_key_here
```

Both `DR_MODEL_PATH` and `GEMINI_API_KEY` are optional — a missing model drops
you to `real_no_cnn` mode, and a missing key falls back to canned report prose.

### 4. Run

On Windows, from the repository root:

```powershell
.
un-local.ps1
```

It creates `.venv` on first run, installs the dependencies and loads `.env`.
Or by hand:

```bash
cd app/python
python app.py
```

Open <http://localhost:5000>:

| Page | What it is |
|------|------------|
| `/` | Animated landing page |
| `/scan` | Upload a fundus image, get the grade, download the PDF |
| `/how-it-works` | Scroll-driven walkthrough of the six pipeline stages |
| `/simulink` | District capacity model, run live in MATLAB |
| `/about` | Mission, team, data, safety and limitations |

`/simulink?preset=growth` opens straight into the 150,000-patient scenario,
which is handy for a demo. The other presets are `minimum` and `slow`.

### 5. Deploying

There are two ways to put DRishti online, and they work together.

| | Live server (your laptop) | Website (GitHub Pages) |
|---|---|---|
| Start it | Double-click **Go Live.cmd** (or run `.
un-public.ps1`) | Run `.\publish-site.ps1` after changing the site |
| Address | Random `https://…trycloudflare.com`, new on every start | https://shaurya-web548.github.io/DRishti-site/ (permanent) |
| Screening | Yes, runs MATLAB | Links to the live server when it is online |
| Simulink model | Runs in MATLAB | Runs in the visitor's browser (JavaScript ports) |
| Needs | This laptop on, window open | Nothing, always up |

**Live server.** `Go Live.cmd` starts a production server (waitress, debug off,
bound to `127.0.0.1`), opens a Cloudflare quick tunnel and prints the public
link. It also tells the website, so the website's scan page shows an
"Open live screening" button. Close the window or press Ctrl+C to go offline;
that stops MATLAB and marks the website offline.

- Visitors are rate-limited (10 scans, 30 reports and 120 simulations per
  10 minutes each) and uploaded photographs are deleted after 24 hours.
  Tune with `SCAN_LIMIT`, `REPORT_LIMIT`, `SIMULATE_LIMIT` and
  `RESULTS_MAX_AGE_HOURS` in `.env`.
- **Permanent address.** With a domain on Cloudflare, the live server can keep
  one fixed address (e.g. `https://drishti.example.com`) instead of a new
  random link each time. In the Cloudflare dashboard go to Zero Trust →
  Networks → Tunnels → Create a tunnel (cloudflared), copy its token, and add
  a Public Hostname pointing to `http://localhost:5000`. Put the token in `.env`
  as `CLOUDFLARE_TUNNEL_TOKEN`, set `project.liveUrl` in
  `app/python/content/team.json` to the address, and re-run `publish-site.ps1`
  so the website accepts it. The laptop still has to be on.
  Without the Zero Trust dashboard, create it from PowerShell instead:
  `tools\cloudflared\cloudflared.exe tunnel login`, then `... tunnel create drishti`,
  `... tunnel route dns drishti drishti.example.com` and `... tunnel token drishti`
  (the last one prints the token for `.env`).
- Never expose `run-local.ps1`: it runs Flask's debugger, which must not be
  reachable from the internet.
- Serving MATLAB results publicly is subject to your MATLAB licence terms.

**Website.** `publish-site.ps1` renders the same templates as static files
(`tools/pages/build_pages.py`) and pushes only those files to the public
repository `DRishti-site`, which serves them on GitHub Pages. This code
repository can stay private. The online/offline status lives on that
repository's `live` branch and is written by `tools/live-status.ps1`; the
website also pings the live server's `/api/health` itself, so a laptop that
simply switched off shows as offline.

Links to the source code are hidden on the website while the code
repositories are private. Set `showSourceLinks` to `true` in
`app/python/content/team.json` if you make them public.

---

## Using the MATLAB pipeline directly

Grade a single image without the web layer:

```matlab
addpath('matlab');
report = runDRPipelineProduction("fundus.jpg", ...
    OutputDir = "out", ...
    ModelPath = "models/drClassifier.mat");

disp(report.mode)              % "real_full" or "real_no_cnn"
disp(report.decision.grade)    % 0-4
```

Inspect the segmentation on its own:

```matlab
r = segmentRetina('fundus.jpg');
figure, imshow(r.overlay)      % labelled overlay with leader lines
fprintf('%d microaneurysms\n', r.microaneurysms.count);
```

Run the smoke test — it works with no trained model and no fundus image, using an
untrained SqueezeNet head and a synthetic retina:

```matlab
demoExplainGrading
```

---

## Training your own classifier

Sort a labelled dataset into `data/0` … `data/4`:

```matlab
% APTOS 2019
sortIntoGradeFolders('train.csv', 'train_images', 'data', 'id_code', 'diagnosis')

% IDRiD
sortIntoGradeFolders('IDRiD_Disease Grading_Training Labels.csv', ...
    'Training Set', 'data', 'Image name', 'Retinopathy grade')

% Messidor-2
sortIntoGradeFolders('messidor_data.csv', 'IMAGES', 'data', ...
    'image_id', 'adjudicated_dr_grade')
```

**Train on APTOS 2019 only, and keep the other two out of training.**

| Dataset | Role | Why |
|---------|------|-----|
| APTOS 2019 | Training | 3,662 images from Aravind Eye Hospital's Indian screening camps, graded on ICDR 0–4. The closest public match to where DRishti runs, and small enough to train in minutes. |
| Messidor-2 | External test | Different population and camera. Never trained on, so it measures how the model copes with distribution shift. |
| IDRiD | Lesion check | Pixel-level masks of microaneurysms, haemorrhages and exudates, for validating `segmentRetina.m`. |

Merging all three into one training pool would leave nothing independent to
test on. Sort APTOS into `data/0` … `data/4`, the other two into their own
folders, then:

```matlab
model = trainDRClassifier('data', Backbone="efficientnetb0", MaxEpochs=10);
```

`MaxPerClass` defaults to `Inf`, so the whole of APTOS is used. The first demo
checkpoint capped it at 200 images per grade, which threw away about 70% of the
data. Image datastores stream from disk, so the full set does not need to fit in
memory. Pass `MaxPerClass=200` only for a quick smoke test.

Then tune the operating point and calibrate:

```matlab
pRefVal  = sum(model.valScores(:, model.grades >= 2), 2);
opPoint  = tuneReferableThreshold(pRefVal, model.valGrades >= 2, 0.90, 0.85);
model.referableThreshold = opPoint.threshold;

[rawVal, i] = max(model.valScores, [], 2);
model.calibration = calibrateConfidence(rawVal, model.grades(i)' == model.valGrades, Plot=true);

save('models/drClassifier.mat', '-struct', 'model');
```

`runDRPipelineProduction.m` reads `model.referableThreshold`, so setting it is
what moves the app off the placeholder `grade >= 2` cut-off.

## About the checkpoint in `models/`

`drClassifier.mat` is a **demo checkpoint**, not a validated model. It comes from
a short fine-tune — 3 epochs, 525 iterations, Adam at 1e-4, best-validation
checkpointing, on a 200-image-per-class subsample of APTOS 2019, about two and a
half minutes on a single GPU. It is there so the app boots into `real_full` mode
and the Grad-CAM and confidence paths are exercisable out of the box. It is not
accurate enough to screen anyone. Retrain on the full dataset for anything real.

The datasets themselves are not redistributed here. Get them from their sources:
[APTOS 2019](https://www.kaggle.com/c/aptos2019-blindness-detection),
[IDRiD](https://idrid.grand-challenge.org/),
[Messidor-2](https://www.adcis.net/en/third-party/messidor2/).

## Known limitations

- The neovascularization flag is a heuristic proxy and fires on dense normal arcades.
- Haemorrhages are localised but not sub-typed (dot / blot / flame).
- Venous beading and IRMA are accepted as inputs to `gradeByRules.m` but are not
  detected by `segmentRetina.m` — two of the three severe-NPDR triggers therefore
  depend on external input.
- Scan state is kept in memory in `app.py`; it does not survive a restart.
- The MATLAB Engine is a process-wide singleton with a call lock, so scans are
  serialised — fine for a kiosk, not for concurrent load.

## License

MIT — see [LICENSE](LICENSE).
