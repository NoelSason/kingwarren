# DataHacks 2026 Requirements Brief

Last updated: April 18, 2026  
Scope: condensed working brief for a team building an ML + bio project at DataHacks 2026.  
Source basis: organizer handbook and dataset notes provided in chat, not live-verified against external links. See [References](#references).

## 1. What We Must Satisfy

### Core competition rules

- We must be students at an accredited college or university. [1]
- Only registered hackers are eligible to participate. [1]
- Teams can have `1-4` members. [1]
- A person can only be on one team. [1]
- Team and project names must be appropriate for a professional environment. [1]
- We can submit one project to up to `2 tracks`. [1]
- All project materials must be created during the hackathon timeframe. Reusing an old project is not allowed, and organizers will check GitHub repos. [1]
- Plagiarism, sabotage, and rule bypassing are prohibited. [1]

### Theme + dataset requirement

- All projects are expected to tie into the event theme revealed at the Opening Ceremony. [1]
- For `ML/AI`, `Data Analytics`, `Cloud`, `UI/UX & Web Development`, `Economics`, and `Product & Entrepreneurship`, we must integrate at least `one provided dataset` as a core part of the project. [1]
- The user note adds a stricter interpretation for software projects: if we are doing a software-based project, we must use at least one of the listed datasets. [2]
- To be eligible for the `$1500 Scripps Challenge`, we must specifically use at least `one Scripps dataset`. [2]

### What this means for our team

- If we are submitting to `ML/AI`, dataset usage is mandatory. [1]
- If we want the strongest eligibility position, we should use a `Scripps dataset` and make it central to the model, not just decorative. [2]
- Because our direction is `ML + bio`, the safest framing is:
  - biological prediction, detection, ranking, or recommendation
  - built directly from a listed dataset
  - easy to explain as a real user tool or scientific decision support system

## 2. Best Dataset Options For ML + Bio

### Best Scripps options for our use case

- `CalCOFI Data Portal`  
  Good for marine ecosystem modeling, plankton, fish larvae, ocean chemistry, and long-term ecological change. Strong fit for marine biology + ML. [2]
- `iNaturalist Species Data`  
  Good for species observations, biodiversity mapping, species prediction, and computer vision workflows. Useful if we want something user-facing. [2]
- `Heat Map Data`  
  Good for urban heat + public health + habitat/pollinator/biodiversity correlations on UCSD campus. Very demo-friendly because we can connect it to campus reality. [2]
- `Spray Data`  
  Good for California coastal water properties and seasonal ocean changes. Useful for habitat stress, bloom prediction, or biological condition forecasting. [2]
- `CCE Mooring Data`  
  Good for surface and subsurface ocean conditions, ocean acidification markers, and ecological stress alerts. Strong for anomaly detection or forecasting. [2]
- `EasyOneArgo Data`  
  Good for large-scale ocean temperature and salinity trends. Useful for broader marine condition modeling, but likely heavier to operationalize in a short hackathon. [2]

### Less relevant Scripps options for our current direction

- `Geophysics earthquake datasets` are strong technically, but they are a weaker fit for `bio` unless we force the biology angle. [2]
- `Sea Surface Height Data for the Gulf of Mexico` is more ocean-physics-focused and may be harder to connect tightly to a biology user story within the weekend. [2]

### Recommended dataset strategy

- Use `one Scripps dataset` as the primary dataset so challenge eligibility is clear. [2]
- If useful, combine a Scripps dataset with another allowed dataset for a stronger story.
- Strong pairings:
  - `iNaturalist + Heat Map Data`
  - `iNaturalist + CalCOFI`
  - `CalCOFI + CCE Mooring`
  - `Spray + CCE Mooring`

## 3. Project Framing Requirements

To stay competitive and compliant, our project should satisfy all of these:

- Uses at least one listed dataset as a `core` input, not as an afterthought. [1][2]
- Clearly ties to the event theme once that is revealed. [1]
- Shows obvious ML value:
  - prediction
  - classification
  - anomaly detection
  - ranking/recommendation
  - clustering with a clear biological use case
- Has a short, testable demo.
- Has a GitHub repo with visible hackathon-time development history. [1]

## 4. Submission Requirements

### Devpost requirements

To remain eligible for prizes, the Devpost submission must include: [1]

- team members
- team name
- GitHub repository link
- 3-minute demo video covering:
  - inspiration: what problem we are solving
  - development: how we built it
  - demo: project in action
- selected tracks
- selected sponsor challenges, if applicable

### Important video requirement

- If we submit to a sponsor challenge, we must explicitly say in the demo video how we satisfied that challenge requirement. [1]

## 5. Deadlines We Cannot Miss

### Saturday, April 18, 2026

- `8:00-9:30 AM`: check-in + breakfast [1]
- `10:30 AM`: latest check-in for UCSD students [1]
- `12:00 PM`: latest check-in for non-UCSD students [1]
- `12:00 PM`: team and track registration form due [1]

### Sunday, April 19, 2026

- `12:00 PM`: soft submission deadline [1]
- `1:00 PM`: hard submission deadline, no late submissions [1]
- `2:00-4:30 PM`: judging [1]
- `5:30-7:00 PM`: awards ceremony [1]

## 6. Working Checklist For Our Team

### Before building

- Confirm final team roster.
- Decide our `1-2 tracks`.
- Decide whether we are also targeting the `Scripps Challenge`.
- Lock one primary dataset and download or access it.
- Confirm the project ties to the revealed theme.
- Create the GitHub repo immediately so our work is visibly within hackathon time. [1]

### During building

- Keep a clean README with:
  - problem
  - dataset used
  - model approach
  - setup instructions
  - demo instructions
- Save screenshots and short clips as we go for the demo video.
- Track exactly how the dataset is used so we can explain it cleanly to judges.
- Build a simple demo flow that works in under 1 minute.

### Before submission

- Fill out Devpost before the soft deadline. [1]
- Confirm GitHub repo link works.
- Confirm demo video is under 3 minutes.
- Confirm tracks and challenges are selected correctly.
- Confirm the submission clearly states which dataset was used and how.

## 7. Hardware Available

### Provided hardware

- `Sensors Kit`: 1 per team, can keep it. [1]
- `Qualcomm Arduino Uno Q Kit`: 1 per individual, must be returned. [1]

### Arduino Uno Q kit components

- Arduino Uno Q chip [1]
- Logitech webcam [1]
- Modulino Distance [1]
- Modulino Movement [1]
- Modulino Thermo [1]
- USB-C multiport adapter for Mac [1]
- wiring [1]

### When hardware helps

Hardware is optional for us, but it can strengthen the demo if we use it as:

- a live sensor input node
- a webcam-based species or object detector
- a real-time environment monitor that feeds the model

If we use hardware, the dataset should still remain central so our submission remains clearly compliant. [1][2]

## 8. Useful Logistics

### Venue

- Main venue: `UC San Diego Rec Gym`, `2999 Scholars Ln, La Jolla, CA 92093`. [1]
- Workshops also occur in `Price Center Theater`, `3135 Matthews Ln, La Jolla, CA 92093`. [1]

### Wi-Fi

- UCSD affiliates: `UCSD-PROTECTED` [1]
- Non-UCSD attendees: `eduroam` and `UCSD-Guest` [1]

### What to bring

- government ID and school ID, mandatory for entry [1]
- laptop [1]
- chargers [1]
- headphones [1]
- reusable water bottle [1]
- toiletries and deodorant [1]
- copies of resume if desired [1]
- sleeping gear if staying overnight [1]

### Food provided

- Saturday: breakfast, lunch, dinner [1]
- Sunday: breakfast and lunch [1]
- Sunday dinner is not provided. [1]

## 9. Judging-Oriented Notes

What judges will likely care about, based on the structure of the event:

- the project solves a real problem
- the dataset use is substantive and obvious
- the ML component is real and understandable
- the demo is stable
- the story is tailored to both track judges and challenge judges if we submit to both [1]

The safest pitch structure is:

1. Problem
2. Why existing tools are insufficient
3. Dataset used
4. Model or algorithm
5. Live demo
6. Real-world impact

## 10. Recommended Direction For Us

If our goal is `ML + bio + user-facing + Scripps eligible`, the best dataset directions are:

- `iNaturalist + CalCOFI`
- `iNaturalist + Heat Map Data`
- `CalCOFI` alone for marine biology forecasting
- `CCE Mooring` for marine stress or acidification alerts

The strongest practical framing is:

- biodiversity prediction
- species recommendation or identification
- habitat stress forecasting
- ecological alerting

## 11. Open Items To Verify Fast

These were referenced in the handbook text but not fully included in the pasted material:

- final track rubric details [1]
- full sponsor challenge descriptions and prize page [1]
- the theme revealed during opening ceremony [1]
- the exact live link for the required dataset bank [1]

We should verify these directly on the official event pages or Discord before final submission.

## References

[1] `DataHacks 2026 Hacker Handbook` excerpt provided in the chat, including sections on overview, rules, schedule, hacking, submission requirements, logistics, and hardware.

[2] `DataHacks dataset notes / required dataset bank summary` provided in the chat, including Scripps and non-Scripps datasets and the note that software-based projects must use one of the listed datasets, with Scripps dataset usage required for the Scripps Challenge.
