// Builds the DRishti project report.
//
//   cd tools/report
//   npm install                    (first time)
//   node build_report.js           -> out/DRishti_Project_Report.docx
//   .inish_report.ps1            -> fills the contents list, writes the PDF
//
// Numbers come from report_data.json (regenerate with collectReportData.m in
// MATLAB) and measurements.json. The team comes from
// app/python/content/team.json, so filling that file in and re-running this
// script updates the report and the About page together.

const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, AlignmentType, LevelFormat, Footer,
  PageNumber, TableOfContents, BorderStyle,
} = require('docx');
const H = require('./docx_helpers');

const ROOT = path.resolve(__dirname, '..', '..');
const OUT_DIR = path.join(__dirname, 'out');
const FIG = (name) => path.join(__dirname, 'figures', name);

const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'report_data.json'), 'utf8'));
const meas = JSON.parse(fs.readFileSync(path.join(__dirname, 'measurements.json'), 'utf8'));
const team = JSON.parse(fs.readFileSync(path.join(ROOT, 'app', 'python', 'content', 'team.json'), 'utf8'));

/* --------------------------------------------------------------- format */
const n0 = (v) => Math.round(v).toLocaleString('en-US');
const n1 = (v) => Number(v).toFixed(1);
const pct = (v) => `${n1(v)}%`;
const util = (r, key) => r.utilisation.find((u) => u.key === key).pct;
const blank = (label) => ({ text: `[${label}]`, fill: true });
const orBlank = (value, label) => (value && String(value).trim() ? value : blank(label));

const base = data.baseline;
const project = team.project || {};

/* ================================================================ title */
function titlePage() {
  const members = (team.members || []).map((m, i) => new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { after: 40 },
    children: H.runs(m.name && m.name.trim() ? m.name : blank(`Team member ${i + 1} name`), { size: 24 }),
  }));
  const mentor = (team.mentors || [])[0] || {};
  return [
    new Paragraph({ spacing: { before: 1200 }, children: [] }),
    new Paragraph({ alignment: AlignmentType.CENTER, children: H.runs('PROJECT REPORT', { size: 22, color: H.MOSS, bold: true }) }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 200, after: 120 },
      children: H.runs(project.name || 'DRishti', { size: 76, bold: true, color: H.INK, font: 'Cambria' }) }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 480 },
      children: H.runs('Diabetic retinopathy screening that a district can actually run', { size: 28, italics: true, color: '33443A', font: 'Cambria' }) }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 60 },
      children: H.runs([project.event || 'Smart India Hackathon', project.problemStatement ? ` · Problem statement ${project.problemStatement}` : ''], { size: 22, color: H.MUTED }) }),
    new Paragraph({
      alignment: AlignmentType.CENTER, spacing: { before: 600, after: 160 },
      border: { top: { style: BorderStyle.SINGLE, size: 6, color: H.AMBER, space: 12 } },
      children: H.runs('Submitted by', { size: 20, color: H.MUTED, bold: true }),
    }),
    ...members,
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 400, after: 40 }, children: H.runs('Under the guidance of', { size: 20, color: H.MUTED, bold: true }) }),
    new Paragraph({ alignment: AlignmentType.CENTER, children: H.runs(orBlank(mentor.name, 'Mentor name'), { size: 24 }) }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 500 },
      children: H.runs(orBlank(project.institution, 'Institution name'), { size: 24, bold: true }) }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 80 }, children: H.runs('September 2026', { size: 22, color: H.MUTED }) }),
  ];
}

/* ============================================================= abstract */
function abstract() {
  return [
    new Paragraph({ heading: 'Heading1', pageBreakBefore: true, children: [new TextRun('Abstract')] }),
    H.p(`Diabetic retinopathy is a leading cause of preventable vision loss in working-age adults. It is symptomless until late and treatable when caught early, so every person with diabetes should have their retina examined once a year. In rural districts that examination rarely happens, because grading a retinal photograph needs specialist time that is not available.`),
    H.p(`DRishti is a screening system for that setting. A technician photographs the eye; a quality gate rejects images that cannot be graded; a classical image-analysis pipeline locates the optic disc, fovea, vessels and three lesion types; and two independent graders, one applying the International Clinical DR scale directly and one a fine-tuned convolutional network, grade the image. When they agree the grade stands; when they disagree the case goes to a human. The clinic receives a colour-coded lesion overlay and the patient a plain-language PDF report.`),
    H.p(`Because a screening programme fails at its narrowest queue, not at its model, we also built a district capacity model: a discrete-event simulation of every patient and a Simulink flow model of the same pipeline, run over ${base.params.workingDays} working days. At ${n0(base.params.annualPatients)} patients a year the ophthalmologist runs at ${pct(util(base, 'ophthalmologist'))} of appointment slots while compute runs at ${pct(base.des.computeUtil24hPct)} of the day. The binding constraint is specialist time, not AI throughput, and the specialist queue saturates between 100,000 and 150,000 patients a year.`),
    H.p(`The system runs end to end on base MATLAB. A pure-MATLAB compatibility layer replaces the Image Processing Toolbox functions the pipeline needs, and the Simulink block diagram is solved in base MATLAB when Simulink is not installed. A web application exposes screening, a scroll-driven explanation of the method, and the capacity model as live, interactive tools.`),
    H.p([{ text: 'Keywords: ', bold: true }, 'diabetic retinopathy, fundus imaging, screening, ICDR scale, image segmentation, transfer learning, Simulink, discrete-event simulation, capacity planning.']),
  ];
}

function contents() {
  return [
    new Paragraph({ heading: 'Heading1', pageBreakBefore: true, children: [new TextRun('Contents')] }),
    // Filled in by finish_report.ps1 (Word updates the field and exports the PDF).
    new TableOfContents('Contents', { hyperlink: true, headingStyleRange: '1-2' }),
  ];
}

/* ========================================================== chapter 1 */
function introduction() {
  return [
    H.h1('1. Introduction'),
    H.h2('1.1 Background'),
    H.p('Diabetic retinopathy (DR) is damage to the small blood vessels of the retina caused by prolonged high blood sugar. It progresses through recognisable stages: microaneurysms first, then haemorrhages and hard exudates, and finally abnormal new vessels that can bleed and detach the retina. The disease produces no symptoms until the damage is advanced, yet progression can usually be slowed or halted by glycaemic control, laser photocoagulation or anti-VEGF injections if it is detected early. The clinical benefit therefore comes almost entirely from screening people who feel well.'),
    H.p('Severity is graded on the International Clinical Diabetic Retinopathy (ICDR) scale [1], summarised in Table 1. Grade 2 and above is conventionally referable to an ophthalmologist.'),
    ...H.table(['Grade', 'Name', 'Findings', 'Action'], [
      ['0', 'No apparent DR', 'No abnormalities', 'Annual rescreening'],
      ['1', 'Mild NPDR', 'Microaneurysms only', 'Annual rescreening'],
      ['2', 'Moderate NPDR', 'More than microaneurysms, less than severe', 'Refer'],
      ['3', 'Severe NPDR', '4-2-1 rule: >20 haemorrhages in each of 4 quadrants, venous beading in ≥2 quadrants, or IRMA in ≥1 quadrant', 'Refer'],
      ['4', 'Proliferative DR', 'Neovascularisation, or vitreous / pre-retinal haemorrhage', 'Refer urgently'],
    ], [0.1, 0.2, 0.5, 0.2], { caption: 'The ICDR severity scale used throughout DRishti.' }),
    H.h2('1.2 Problem statement'),
    H.p('Guidelines recommend annual retinal screening for everyone with diabetes. That commitment is not met in rural districts because each photograph must be graded by trained eyes and there are too few specialists to look at everyone. The task is to build a screening system that a district could operate: it must grade photographs reliably, explain its grades, say when it is unsure, and fit inside the people, bandwidth and compute a district actually has.'),
    H.h2('1.3 Why a more accurate model is not enough'),
    H.p('Suppose a perfect grader existed tomorrow. A programme would still have to put a camera and an operator in front of every patient, move the images somewhere they can be processed, have humans review the uncertain cases, and get every positive in front of a specialist. Each of those is a queue with finite capacity, and the programme fails at whichever saturates first. A model that flags more cases makes the last queue worse. DRishti therefore treats the screening programme, not only the model, as the thing to be designed, and Chapter 6 measures it.'),
  ];
}

/* ========================================================== chapter 2 */
function objectives() {
  return [
    H.h1('2. Objectives'),
    ...H.callout('Central claim', 'A screening programme is a chain of queues, and it breaks at the narrowest one. We built the grader, and we measured the chain.'),
    ...H.numbered([
      'Grade a single fundus photograph on the ICDR scale and decide whether the patient should be referred.',
      'Reject photographs that cannot support a grade instead of guessing, so the technician can retake them at the camp.',
      'Make every grade inspectable: show the lesions and criteria behind it.',
      'Never auto-report a result on a single opinion: two independent graders must agree, otherwise a human reviews.',
      'Keep working when components are missing: no trained network, no toolbox, no network connection or no language-model key.',
      'Model the whole district programme to find which resource limits how many people can be screened.',
      'Deliver all of this through a web application usable at a screening camp, including offline.',
    ]),
  ];
}

/* ========================================================== chapter 3 */
function literature() {
  return [
    H.h1('3. Literature review and datasets'),
    H.h2('3.1 Automated DR screening'),
    H.p('Deep learning has matched specialist graders on referable-DR detection in large validation studies; Gulshan et al. [12] reported high sensitivity and specificity with an Inception-v3 network trained on over 100,000 graded images. Such systems are accurate but opaque: they return a probability without the findings behind it. Classical image analysis offers the opposite trade-off. Matched filters detect vessels as elongated Gaussian profiles [8]; contrast-limited adaptive histogram equalisation (CLAHE) [9] corrects uneven illumination; morphological top-hat transforms isolate small bright or dark structures such as microaneurysms. These operators are individually explainable, and a clinician can check what they found.'),
    H.p('DRishti uses both: a classical pipeline that applies the clinical rules directly and can show its working, and an EfficientNet-B0 network [5] fine-tuned by transfer learning. Grad-CAM [6] shows where the network looked, and Platt scaling [7] converts its raw scores into calibrated probabilities.'),
    H.h2('3.2 Choosing the dataset'),
    H.p('The network is only as useful as the data it learns from, so the dataset was chosen for fit to the deployment setting and for training cost, not for size alone (Table 2).'),
    ...H.table(['Dataset', 'Size', 'Labels', 'Role in DRishti', 'Reason'], [
      ['APTOS 2019 [2]', '3,662 train images', 'ICDR 0–4', 'Training', 'Aravind Eye Hospital, Indian screening camps; same scale we report; trains in minutes'],
      ['Messidor-2 [3]', '1,748 images', 'ICDR grades', 'External test', 'Different population and camera; measures distribution shift'],
      ['IDRiD [4]', '516 images', 'Grades + pixel lesion masks', 'Segmentation check', 'Indian images with outlines of the lesions segmentRetina detects'],
      ['EyePACS', '88,702 images', 'ICDR 0–4', 'Not used', 'US programme, widely varying quality, far costlier to train on'],
    ], [0.16, 0.16, 0.18, 0.18, 0.32], { caption: 'Candidate datasets and the role each plays.' }),
    H.p('APTOS 2019 is the most efficient training set for this project: it is the public dataset closest to the camps DRishti targets, it uses the same labels, and it is small enough to train on a 6 GB GPU. Messidor-2 and IDRiD are deliberately kept out of training. Merging them in would leave nothing independent to test against, and the failure mode that ends real screening deployments is a model that has only learned one clinic’s camera.'),
    ...H.callout('Change made during this project', [
      'The original training script capped APTOS at 200 images per grade, discarding about 70% of the data. The cap is now an option that defaults to the full dataset. Image datastores stream from disk, so the full set does not need to fit in memory.',
    ], H.MOSS),
  ];
}

/* ========================================================== chapter 4 */
function design() {
  return [
    H.h1('4. System design'),
    H.h2('4.1 Architecture'),
    H.p('DRishti has three layers. The browser front end is plain HTML, CSS and SVG. A Flask server holds a single long-lived MATLAB Engine session, so scans do not pay MATLAB’s start-up cost. MATLAB runs the image-analysis pipeline, both graders and the capacity models. The MATLAB and web layers meet at a JSON file, so either side can be replaced without touching the other.'),
    H.h2('4.2 Pipeline stages'),
    ...H.table(['Stage', 'What it does', 'Source'], [
      ['1. Quality gate', 'Field of view by circular Hough transform, blur by Laplacian variance, exposure by histogram. Pass, enhance (CLAHE) or reject.', 'assessImageQuality.m'],
      ['2. Segmentation', 'Optic disc, fovea, vessels by 24 matched filters, microaneurysms, exudates, haemorrhages, experimental new-vessel proxy.', 'segmentRetina.m'],
      ['3a. Rule grading', 'ICDR scale applied to quadrant lesion counts, including the 4-2-1 rule.', 'gradeByRules.m'],
      ['3b. CNN grading', 'EfficientNet-B0 on APTOS 2019; calibrated confidence; referral threshold at ≥90% sensitivity.', 'predictDRGrade.m'],
      ['3c. Consensus', 'Agree: grade stands. Disagree: human review, referable if either grader says so.', 'combineGrades.m'],
      ['4. Explanation', 'Lesion overlay, Grad-CAM map, JSON and PNG export.', 'drawLesionOverlay.m, gradCAMHeatmap.m'],
      ['5. Delivery', 'Flask app, MATLAB bridge, PDF report with plain-language text.', 'app.py, report_generator.py'],
    ], [0.18, 0.56, 0.26], { caption: 'The five pipeline stages.' }),
    H.h2('4.3 Runtime modes'),
    ...H.table(['Mode', 'When', 'What the clinic receives'], [
      ['real_full', 'A trained network loads', 'Consensus grade, Grad-CAM, calibrated confidence, lesion overlay'],
      ['real_no_cnn', 'No usable network', 'Rule-based ICDR grade and lesion overlay; no Grad-CAM or confidence'],
    ], [0.18, 0.3, 0.52], { caption: 'The pipeline selects its mode automatically.' }),
    H.h2('4.4 Degrading instead of failing'),
    ...H.bullets([
      [{ text: 'No trained network: ', bold: true }, 'the rule-based grader still grades, and the report says which mode was used.'],
      [{ text: 'No Image Processing Toolbox: ', bold: true }, 'a pure-MATLAB compatibility layer provides every image function the pipeline needs (Section 7.4).'],
      [{ text: 'No Simulink: ', bold: true }, 'the Simulink block diagram is solved step by step in base MATLAB (Section 7.5).'],
      [{ text: 'No language-model key: ', bold: true }, 'the PDF uses a built-in, clinically neutral paragraph.'],
      [{ text: 'No network at the camp: ', bold: true }, 'images are stored and forwarded when the link returns.'],
    ]),
  ];
}

/* ========================================================== chapter 5 */
function methodology() {
  return [
    H.h1('5. Methodology'),
    H.h2('5.1 Quality gate'),
    H.p('Before any grading, the image is checked. The retinal field of view is located with a circular Hough transform on a downsized copy and cross-checked against an intensity mask; if the circle is implausible a threshold-based mask is used instead. Sharpness is the variance of the Laplacian of the green channel, where vessel contrast is highest. Exposure is read from the luminance histogram inside the field of view: mean brightness, the fraction of near-black and saturated pixels, and the 2.5th to 97.5th percentile spread. Borderline images are enhanced with CLAHE on the lightness channel and passed on; images that fail outright are rejected so the technician can retake them.'),
    H.h2('5.2 Segmentation'),
    H.p('All thresholds are expressed as fractions of the field-of-view radius, so the same settings transfer across cameras and resolutions. The optic disc is the brightest compact region after vessels are removed by morphological closing. The fovea is the darkest region about two and a half disc diameters to the side of the disc. Vessels are detected by 24 matched filters, two widths and twelve orientations, followed by hysteresis thresholding. Microaneurysms are small bright spots in the inverted green channel isolated by a top-hat transform. Exudates are bright deviations from a large median-filtered background. Haemorrhages are dark deviations away from the vessels that pass size, width and solidity tests. New vessels are flagged by an experimental proxy that looks for vessel clusters that are both denser and more tortuous than the peripheral baseline.'),
    H.h2('5.3 Rule-based grading'),
    H.p('Lesions are binned into four quadrants around the optic disc, and the ICDR scale is applied directly. Proliferative signs give grade 4; the 4-2-1 rule gives grade 3; more than microaneurysms gives grade 2; microaneurysms alone give grade 1. Every grade is returned with the criteria that triggered it, so it can be audited.'),
    H.h2('5.4 Neural-network grading'),
    H.p('An ImageNet-pretrained EfficientNet-B0 is fine-tuned on APTOS 2019 with a 70/15/15 split, oversampling of minority grades, random rotation, reflection and scaling, and a raised learning rate on the new classification layer. Performance is measured with quadratic weighted kappa, which penalises a grade that is far from the truth more than one that is adjacent. Confidence is calibrated with Platt scaling [7], and the referral threshold is the most specific operating point among those that reach at least 90% sensitivity, because a missed referable case costs far more than a false alarm.'),
    H.h2('5.5 Consensus'),
    H.p('The two graders are combined conservatively. If they return the same grade and the same referral decision, the result stands. Otherwise the case is marked for human review with no grade, and it is referable if either grader says so. The system is allowed to say that a person should look.'),
    H.h2('5.6 Explanation and reporting'),
    H.p('The clinic receives a colour-coded lesion overlay and, when the network ran, a Grad-CAM map. The patient receives a PDF in plain language. A language model writes those plain-language paragraphs and nothing else: the grade is passed as a fixed input it may not change, and only the grade, the referral flag and the grading mode are sent. No image, name or age leaves the machine.'),
  ];
}

/* ========================================================== chapter 6 */
function capacity() {
  const vol = data.volumeSweep;
  const cmp = data.computeSweep;
  const min = data.minimum;
  return [
    H.h1('6. District capacity model (Simulink)'),
    H.p('This is the project’s major feature. It answers the question a district health office actually asks: with the cameras, bandwidth, servers and people we have, how many patients can we screen, and what breaks first?'),
    H.h2('6.1 Two models'),
    H.p([{ text: 'Discrete-event simulation (DES). ', bold: true }, 'Every patient is simulated individually through capture with retakes, the quality gate, upload, the compute worker pool, human review of disagreements and a quality-assurance sample, and ophthalmologist appointment slots. Queues are first-in first-out, shift-bound staff only work inside their hours, and upload and compute run around the clock. The DES produces waiting-time distributions and percentiles and is the reference for every reported utilisation.']),
    H.p([{ text: 'Simulink flow model. ', bold: true }, 'The same pipeline as a discrete-time fluid model built from Simulink blocks. Each stage is a backlog integrator; working hours are sample-based pulse generators; the solver is fixed-step at 15 minutes. It shows the daily burst-and-drain shape of each queue and where backlog accumulates. For each stage and step:']),
    H.p([{ text: 'offered = inflow + backlog / Δt;   flow = min(offered, capacity);   backlog ← max(0, backlog + (inflow − flow) · Δt)', code: true }], { align: AlignmentType.CENTER }),
    H.p('The integrator uses forward Euler, which has no direct feedthrough and so breaks the backlog-to-flow algebraic loop. Running both models and comparing their annual totals (Section 6.6) checks that no parameter was mistranslated between them.'),
    H.h2('6.2 Baseline results'),
    H.p(`The baseline is ${n0(base.params.annualPatients)} patients a year across ${base.params.sites} camps with ${base.params.workers} compute workers at ${base.params.procMeanSec} s per image, ${base.params.graderFTE} graders and ${base.params.ophthFTE} ophthalmologist.`),
    ...H.table(['Resource', 'Utilisation', 'Basis'], base.utilisation.map((u) => [u.label, pct(u.pct), u.basis]),
      [0.4, 0.2, 0.4], { numeric: [1], caption: `Baseline utilisation (DES, ${base.params.workingDays} working days).`, highlightRow: 4 }),
    ...H.figure(FIG('fig-simulink-baseline.png'), 'The Simulink model page in the web app, baseline scenario: the bottleneck verdict, the animated block diagram and utilisation bars, all computed live in MATLAB.'),
    ...H.table(['Measure', 'Result'], [
      ['Patients screened', `${n0(base.des.patientsScreened)} of ${n0(base.params.annualPatients)}`],
      ['Demand that could not be seated', pct(base.des.unmetDemandPct)],
      ['Ungradable after retakes', pct(base.des.ungradableRatePct)],
      ['Images uploaded per year', `${n0(base.des.imagesUploaded)} (${n0(base.des.gbPerYear)} GB)`],
      ['Automated result, median', `${n1(base.des.autoMedianMin)} min after capture`],
      ['Result before the patient leaves the camp', pct(base.des.sameSessionPct)],
      ['Full report including human review, 95th percentile', `${n1(base.des.turnaroundP95H * 60)} min`],
    ], [0.6, 0.4], { numeric: [1], caption: 'What the baseline programme delivers.' }),
    ...H.callout('Key finding', `Compute is not the bottleneck; the ophthalmologist is. At baseline the specialist runs at ${pct(util(base, 'ophthalmologist'))} of appointment slots while the compute workers are busy ${pct(base.des.computeUtil24hPct)} of the day. Specialist time, not AI throughput, determines how large this programme can grow.`),
    H.h2('6.3 Scaling up'),
    ...H.table(['Patients / year', 'Technician', 'Compute', 'Graders', 'Ophthalmologist', 'Specialist wait p95'],
      vol.map((r) => [n0(r.params.annualPatients), pct(util(r, 'technician')), pct(util(r, 'compute')), pct(util(r, 'grader')),
        { text: pct(util(r, 'ophthalmologist')), bold: util(r, 'ophthalmologist') >= 100 }, `${n0(r.des.referralP95WaitDays)} days`]),
      [0.18, 0.15, 0.15, 0.15, 0.19, 0.18], { numeric: [0, 1, 2, 3, 4, 5], caption: 'Utilisation as annual volume grows (compute and technician on a session-hours basis).' }),
    H.p(`The specialist queue passes 100% between 100,000 and 150,000 patients a year. Past that point the backlog never clears: at 150,000 patients the flow model ends the year with ${n0(data.growth.referralBacklogEndOfYear)} patients waiting (Figure ${2}).`),
    ...H.figure(FIG('fig-referral-backlog.png'), 'Specialist backlog at the end of each working day at 150,000 patients a year. The line never comes down: the clinic can never catch up.', 520),
    H.h2('6.4 Sensitivity to processing time'),
    H.p('The compute conclusion rests on one estimated number, the processing time per image. It was swept with a single worker:'),
    ...H.table(['Seconds / image', 'Worker session utilisation', 'Compute wait p95', 'Result before leaving camp'],
      cmp.map((r) => [String(r.params.procMeanSec), pct(util(r, 'compute')), `${n1(r.des.computeP95WaitMin)} min`, pct(r.des.sameSessionPct)]),
      [0.22, 0.28, 0.24, 0.26], { numeric: [0, 1, 2, 3], caption: 'One compute worker at increasing processing times.' }),
    H.p('One worker holds same-session results up to about 24 seconds per image; beyond that the queue does not drain inside the session and same-session delivery collapses. On our test machine the full pipeline took about 9 seconds per image once warm (Section 8.2), inside this margin.'),
    H.h2('6.5 Minimum feasible configuration'),
    H.p(`Searching for the smallest allocation that keeps every resource under 85%, unmet demand below 2% and the specialist wait under 14 days gives ${min.params.sites} camps, ${min.params.workers} compute worker, ${min.params.graderFTE} grader and ${min.params.ophthFTE} ophthalmologist. Verified as a combined configuration: ${n0(min.des.patientsScreened)} screened, ${pct(min.des.unmetDemandPct)} unmet, highest utilisation ${pct(min.bottleneck.pct)} (${min.bottleneck.label.toLowerCase()}). The baseline had over-bought compute and graders and under-bought screening camps; the model corrected our own guess.`),
    H.h2('6.6 Cross-checking the two models'),
    ...H.table(['Quantity', 'Flow model', 'DES', 'Difference'],
      base.validation.map((v) => [v.quantity, n0(v.flow), n0(v.des), `${v.diffPct > 0 ? '+' : ''}${n1(v.diffPct)}%`]),
      [0.4, 0.2, 0.2, 0.2], { numeric: [1, 2, 3], caption: 'Annual totals, Simulink flow model versus discrete-event reference (baseline).' }),
    H.p('The flow model is deterministic and serves every arrival, while the DES turns away patients a session cannot seat, so the flow model runs a few percent high. Agreement within about 4% on every quantity confirms the two models encode the same programme.'),
  ];
}

/* ========================================================== chapter 7 */
function implementation() {
  return [
    H.h1('7. Implementation'),
    H.h2('7.1 Technology stack'),
    ...H.table(['Component', 'Technology', 'Purpose'], [
      ['Image analysis and grading', 'MATLAB R2026a', 'Quality gate, segmentation, both graders, explanation'],
      ['Capacity models', 'MATLAB, Simulink', 'Discrete-event simulation and flow model'],
      ['Neural grader', 'EfficientNet-B0', 'Transfer-learned DR classifier'],
      ['Web server', 'Python 3.12, Flask', 'Pages and JSON API'],
      ['MATLAB bridge', 'MATLAB Engine for Python', 'Persistent engine session'],
      ['Reports', 'fpdf2, Gemini', 'PDF layout; plain-language text only'],
      ['Front end', 'HTML, CSS, SVG, JavaScript', 'Animated interface with no external libraries, works offline'],
      ['Testing', 'pytest, Playwright, MATLAB', 'Unit, integration and browser checks'],
    ], [0.3, 0.3, 0.4], { caption: 'Technology stack.' }),
    H.h2('7.2 Web application'),
    H.p('The application has five pages. The landing page opens with an animated retina drawn procedurally in SVG: its vessels draw themselves, a scan sweep passes and each detected structure is ringed and labelled in turn. The screening page takes an upload and returns the grade, referral decision, overlay and report. The How-it-works page is a scroll-driven story in which the same retina changes as each pipeline stage comes into view. The Simulink page runs the capacity model live. The About page presents the mission, team, data, safety measures and limitations. All motion respects the operating system’s reduced-motion setting.'),
    ...H.figure(FIG('fig-landing.png'), 'Landing page. The highlighted amber button opens the Simulink capacity model.'),
    ...H.figure(FIG('fig-how-segment.png'), 'How-it-works page at the segmentation stage: detected vessels in blue, the optic disc and fovea ringed.'),
    ...H.figure(FIG('fig-scan.png'), 'Screening page.'),
    ...H.figure(FIG('fig-simulink-growth.png'), 'Simulink page at 150,000 patients a year: the referral block turns red and the verdict reports that its queue never drains.'),
    H.h2('7.3 Input validation and security'),
    ...H.bullets([
      [{ text: 'Patient age ', bold: true }, 'must be a whole number from 0 to 120. The browser refuses minus signs and exponents as they are typed, and the server checks the same rule again, so a negative age can never reach a report.'],
      [{ text: 'Capacity scenarios ', bold: true }, 'accept only nine named parameters, each range-checked in Python and again in MATLAB. Unknown keys and non-numbers are rejected, not clamped.'],
      [{ text: 'Result files ', bold: true }, 'are served only for well-formed scan identifiers and through a path-safe file sender, closing a path-traversal hole found during this work.'],
      [{ text: 'Patient data ', bold: true }, 'stays on the screening server; see Section 5.6 for what the language model receives.'],
    ]),
    H.h2('7.4 Running without the Image Processing Toolbox'),
    H.p('The pipeline calls about thirty Image Processing Toolbox functions, but base MATLAB includes only a handful of image functions: reading, writing, resizing and basic colour conversion. A compatibility layer in matlab/compat implements the rest in plain MATLAB and is added to the path only when the real toolbox is absent. Several needed careful algorithms to be usable at 1024-pixel resolution:'),
    ...H.bullets([
      'Disk-shaped morphology is decomposed into horizontal chords computed with running max/min, reducing an O(r²) scan to O(r) passes.',
      'The 53×53 median filter for background estimation walks intensity levels with separable box sums; a naive stack would need tens of gigabytes.',
      `The distance transform is exact, using Felzenszwalb and Huttenlocher’s lower-envelope algorithm [11]. Skeletons use Zhang–Suen thinning [10] evaluated only on foreground pixels, which cut segmentation from ${n1(meas.segmentRetinaSecondsBefore)} s to ${n1(meas.segmentRetinaSecondsAfter)} s.`,
      'CLAHE, Otsu thresholding [13], connected components, region properties and the circular Hough transform are implemented to the toolbox’s published definitions.',
    ]),
    H.p(`The layer is covered by ${meas.compatChecks} self-tests written against hand-computed expectations. Bringing the full pipeline up also exposed and fixed four latent integration defects at interfaces that had never run end to end, including one that silently discarded the CLAHE-enhanced image.`),
    H.h2('7.5 Running the Simulink model without Simulink'),
    H.p('drishtiFlowModel.m executes the Simulink block diagram step by step in base MATLAB: the same constants, the same sample-based pulse gates and the same forward-Euler integrators. When Simulink is installed, drishtiRunScenario.m builds and simulates the real model instead and falls back to the base solver if that fails, so the web page always shows which engine ran. The Simulink path is written but untested, because Simulink is not installed on the development machine.'),
  ];
}

/* ========================================================== chapter 8 */
function testing() {
  return [
    H.h1('8. Testing and results'),
    H.h2('8.1 Test suites'),
    ...H.table(['Suite', 'Scope', 'Result'], [
      ['pytest (web layer)', 'Pages, upload and scan flow, report download, age validation, scenario validation, path traversal, team loader', `${meas.pytestTests} passed, ${meas.webLayerCoveragePct}% line coverage`],
      ['testCompat.m', 'Every compatibility-layer function against hand-computed results', `${meas.compatChecks} of ${meas.compatChecks} passed`],
      ['Browser checks (Playwright, Edge)', 'All five pages at phone and desktop width: horizontal overflow, console errors, age-field behaviour, scroll-driven stages', 'No page wider than the screen; no console errors'],
      ['Capacity model', 'Baseline, volume and compute sweeps; minimum configuration; model cross-check', 'Reproduces the published study; models agree within 4%'],
    ], [0.24, 0.5, 0.26], { caption: 'Automated verification.' }),
    H.h2('8.2 Performance'),
    ...H.table(['Measurement', 'Value'], [
      ['Scan, first request (includes MATLAB start-up)', `${meas.scanColdSeconds} s`],
      ['Scan, engine warm', `${meas.scanWarmSeconds} s`],
      ['Segmentation before and after skeleton optimisation', `${n1(meas.segmentRetinaSecondsBefore)} s → ${n1(meas.segmentRetinaSecondsAfter)} s`],
      ['Stored output per scan', `${n1(meas.reportJsonMBBefore)} MB → ${meas.scanFolderKBAfter} KB`],
      ['One capacity scenario (DES + flow model)', `under ${Math.ceil(meas.desSingleRunSeconds)} s`],
    ], [0.62, 0.38], { numeric: [1], caption: `Measured on ${meas.machine}.` }),
    H.p('The stored output shrank because the full-resolution enhanced image was being serialised into every report as JSON numbers; nothing downstream read it.'),
    H.h2('8.3 Grading accuracy'),
    ...H.callout('What we do not claim', 'The shipped network checkpoint is a three-epoch demonstration trained on a small subsample, so no accuracy figure is quoted for it. The evaluation machinery (quadratic weighted kappa, calibration error and the 90%-sensitivity operating point) is implemented; the number will be reported after full training on APTOS 2019 and external testing on Messidor-2.'),
  ];
}

/* ====================================================== chapters 9-11 */
function limitations() {
  return [
    H.h1('9. Limitations'),
    ...H.bullets([
      [{ text: 'Demonstration network. ', bold: true }, 'Not yet trained on the full dataset; no accuracy is claimed.'],
      [{ text: 'Venous beading and IRMA ', bold: true }, 'are not detected automatically, so two of the three severe-NPDR triggers depend on external input. This is the most significant clinical gap.'],
      [{ text: 'New-vessel detection ', bold: true }, 'is an experimental proxy that can fire on dense but normal vessels.'],
      [{ text: 'Haemorrhages ', bold: true }, 'are localised but not sub-typed into dot, blot and flame.'],
      [{ text: 'Scan state ', bold: true }, 'is held in memory and does not survive a server restart; the MATLAB engine serialises scans.'],
      [{ text: 'Capacity model assumptions. ', bold: true }, 'Processing time, referable rate and grader disagreement rate are estimates; weekends and loss to follow-up are not modelled.'],
      [{ text: 'Not a medical device. ', bold: true }, 'DRishti has not been clinically validated.'],
    ]),
  ];
}

function futureScope() {
  return [
    H.h1('10. Future scope'),
    ...H.table(['Priority', 'Work', 'Why'], [
      ['1', 'Train on the full APTOS 2019 set; report quadratic weighted kappa with a confidence interval on Messidor-2', 'Replaces the demonstration checkpoint'],
      ['2', 'Validate segmentation against IDRiD lesion masks', 'Measures the rule-based grader directly'],
      ['3', 'Detect venous beading and IRMA, or restrict the rule grader to the triggers it can see', 'Closes the largest clinical gap'],
      ['4', 'Measure processing time on deployment hardware and feed it back into the capacity model', 'Replaces the most load-bearing estimate'],
      ['5', 'Persist scans in a database with an audit log of human overrides', 'Needed for real deployment; overrides improve the model'],
      ['6', 'Pilot with a district health office on one camp cycle', 'Real disagreement and referable rates'],
    ], [0.1, 0.55, 0.35], { caption: 'Roadmap, ordered by clinical value per unit of work.' }),
  ];
}

function conclusion() {
  return [
    H.h1('11. Conclusion'),
    H.p('DRishti grades retinal photographs on the international clinical scale with two independent graders, refers when either is worried, shows the lesions behind every grade, and keeps running when components are missing. Its capacity model shows that at district scale the limit is specialist time, not compute: at 100,000 patients a year the ophthalmologist runs at three quarters of capacity while the servers are nearly idle, and the specialist queue saturates before 150,000. The most valuable thing an automated screener can do is therefore to spend specialist attention carefully, which is how DRishti was designed. The immediate next step is full training on APTOS 2019 with external testing on Messidor-2, so that the grading accuracy can be reported with the same rigour as the capacity results.'),
  ];
}

/* ============================================================ team page */
function teamChapter() {
  const rows = (team.members || []).map((m, i) => [
    m.name && m.name.trim() ? m.name : blank(`Name ${i + 1}`),
    orBlank(m.role, 'Role'),
    orBlank(m.program, 'Programme / year'),
    orBlank(m.focus, 'Contribution'),
  ]);
  const mentor = (team.mentors || [])[0] || {};
  return [
    H.h1('12. Team'),
    H.p(`${project.name || 'DRishti'} was built for the ${project.event || 'Smart India Hackathon'}${project.problemStatement ? `, problem statement ${project.problemStatement}` : ''}.`),
    ...H.table(['Name', 'Role', 'Programme', 'Contribution'], rows, [0.24, 0.2, 0.2, 0.36], { caption: 'Team members.' }),
    H.p([{ text: 'Mentor: ', bold: true }, orBlank(mentor.name, 'Mentor name'), mentor.affiliation ? `, ${mentor.affiliation}` : '']),
    H.p([{ text: 'Highlighted fields are waiting for team details. ', italics: true, color: H.MUTED },
      { text: 'Fill in app/python/content/team.json and run node build_report.js to regenerate this report; the website’s About page updates from the same file.', italics: true, color: H.MUTED }]),
  ];
}

function references() {
  const refs = [
    'Wilkinson CP, Ferris FL, Klein RE, et al. Proposed international clinical diabetic retinopathy and diabetic macular edema disease severity scales. Ophthalmology. 2003;110(9):1677–1682.',
    'Asia Pacific Tele-Ophthalmology Society. APTOS 2019 Blindness Detection. Kaggle, 2019.',
    'Decencière E, Zhang X, Cazuguel G, et al. Feedback on a publicly distributed image database: the Messidor database. Image Analysis & Stereology. 2014;33(3):231–234.',
    'Porwal P, Pachade S, Kamble R, et al. Indian Diabetic Retinopathy Image Dataset (IDRiD): a database for diabetic retinopathy screening research. Data. 2018;3(3):25.',
    'Tan M, Le QV. EfficientNet: rethinking model scaling for convolutional neural networks. Proceedings of ICML. 2019.',
    'Selvaraju RR, Cogswell M, Das A, et al. Grad-CAM: visual explanations from deep networks via gradient-based localization. Proceedings of ICCV. 2017.',
    'Platt J. Probabilistic outputs for support vector machines and comparisons to regularized likelihood methods. Advances in Large Margin Classifiers. MIT Press; 1999.',
    'Chaudhuri S, Chatterjee S, Katz N, Nelson M, Goldbaum M. Detection of blood vessels in retinal images using two-dimensional matched filters. IEEE Transactions on Medical Imaging. 1989;8(3):263–269.',
    'Zuiderveld K. Contrast limited adaptive histogram equalization. In: Graphics Gems IV. Academic Press; 1994:474–485.',
    'Zhang TY, Suen CY. A fast parallel algorithm for thinning digital patterns. Communications of the ACM. 1984;27(3):236–239.',
    'Felzenszwalb PF, Huttenlocher DP. Distance transforms of sampled functions. Theory of Computing. 2012;8:415–428.',
    'Gulshan V, Peng L, Coram M, et al. Development and validation of a deep learning algorithm for detection of diabetic retinopathy in retinal fundus photographs. JAMA. 2016;316(22):2402–2410.',
    'Otsu N. A threshold selection method from gray-level histograms. IEEE Transactions on Systems, Man, and Cybernetics. 1979;9(1):62–66.',
  ];
  return [
    H.h1('References'),
    ...refs.map((r, i) => new Paragraph({
      spacing: { after: 100, line: 280 },
      indent: { left: 480, hanging: 480 },
      children: H.runs([{ text: `[${i + 1}]  `, bold: true }, r], { size: 20 }),
    })),
  ];
}

function appendix() {
  return [
    H.h1('Appendix A. Running DRishti'),
    H.p([{ text: 'Source code: ', bold: true }, project.repository || '',
      project.previousVersion ? ` (version 1: ${project.previousVersion})` : ''], { align: AlignmentType.LEFT }),
    H.p('On Windows, from the repository root:'),
    H.p([{ text: '.\\run-local.ps1', code: true }], { align: AlignmentType.LEFT }),
    H.p('The script creates a Python virtual environment on first run, installs the dependencies and the MATLAB Engine for Python, loads the .env settings and starts the server at http://localhost:5000.'),
    ...H.table(['Address', 'Page'], [
      ['/', 'Landing page'],
      ['/scan', 'Screen an eye'],
      ['/how-it-works', 'Pipeline walkthrough'],
      ['/simulink', 'District capacity model; add ?preset=growth, minimum or slow'],
      ['/about', 'Mission, team, data, safety and limitations'],
    ], [0.3, 0.7], { caption: 'Web application pages.' }),
    H.p('To regenerate this report: run collectReportData in MATLAB from tools/report, then node build_report.js.'),
  ];
}

/* ============================================================== document */
function footer() {
  return new Footer({
    children: [new Paragraph({
      alignment: AlignmentType.CENTER,
      children: [
        new TextRun({ text: `${project.name || 'DRishti'} · Project report · `, size: 17, color: H.MUTED }),
        new TextRun({ children: [PageNumber.CURRENT], size: 17, color: H.MUTED }),
      ],
    })],
  });
}

const PAGE = { size: { width: 11906, height: 16838 }, margin: { top: 1440, right: 1440, bottom: 1300, left: 1440 } };

const doc = new Document({
  creator: project.name || 'DRishti',
  title: `${project.name || 'DRishti'} - Project Report`,
  description: 'Diabetic retinopathy screening and district capacity model',
  styles: {
    default: { document: { run: { font: 'Calibri', size: 22, color: '1C2A22' } } },
    paragraphStyles: [
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: 'Cambria', size: 36, bold: true, color: H.INK },
        paragraph: { spacing: { before: 120, after: 240 }, outlineLevel: 0,
          border: { bottom: { style: BorderStyle.SINGLE, size: 8, color: H.AMBER, space: 6 } } } },
      { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: 'Cambria', size: 27, bold: true, color: '1F4436' },
        paragraph: { spacing: { before: 280, after: 120 }, outlineLevel: 1, keepNext: true } },
      { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: 'Calibri', size: 23, bold: true, color: H.MOSS },
        paragraph: { spacing: { before: 200, after: 80 }, outlineLevel: 2, keepNext: true } },
    ],
  },
  numbering: {
    config: [
      { reference: 'bullets', levels: [{ level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 540, hanging: 300 } } } }] },
      { reference: 'numbers', levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 540, hanging: 360 } } } }] },
    ],
  },
  sections: [
    { properties: { page: PAGE }, children: titlePage() },
    {
      properties: { page: { ...PAGE, pageNumbers: { start: 1 } } },
      footers: { default: footer() },
      children: [
        ...abstract(), ...contents(), ...introduction(), ...objectives(), ...literature(), ...design(),
        ...methodology(), ...capacity(), ...implementation(), ...testing(), ...limitations(),
        ...futureScope(), ...conclusion(), ...teamChapter(), ...references(), ...appendix(),
      ],
    },
  ],
});

fs.mkdirSync(OUT_DIR, { recursive: true });
const outFile = process.argv[2] || path.join(OUT_DIR, 'DRishti_Project_Report.docx');
Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(outFile, buf);
  console.log(`Wrote ${outFile} (${Math.round(buf.length / 1024)} KB)`);
});
