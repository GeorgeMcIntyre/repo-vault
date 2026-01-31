# Portfolio Value Estimate

**Generated:** 2026-01-31 21:03:45

## Methodology

This estimate calculates the replacement cost of the entire repository portfolio using South African Rand (ZAR) hourly rates.

### Hourly Rates

- **Low tier:** R450/hour
- **Mid tier:** R750/hour
- **High tier:** R1200/hour

### Calculation Method

1. **Base Hours** = min(LOC / 50, 1200)
2. **Quality Factor** = 0.70 + (ProofScore / 100) Ã— 0.70
3. **Estimated Hours** = BaseHours Ã— QualityFactor
4. **Value** = EstimatedHours Ã— HourlyRate

### Proof Score Components (0-100)

- LOC (logarithmic): 0-30 points
- Tests present: 0-15 points
- CI/CD present: 0-10 points
- Documentation: 0-10 points
- Multi-year activity: 0-15 points
- Complexity (files): 0-10 points
- Releases/tags: 0-10 points

## Portfolio Value Summary

| Tier | Total Value (ZAR) |
|------|-------------------|
| Low | R 11 292 660 |
| Mid | R 18 821 100 |
| High | R 30 113 760 |

## Breakdown by Repository

Top 20 repositories by mid-tier value:

| Rank | Owner | Repo | LOC | Commits | Proof | Hours | Value (Mid) |
|------|-------|------|-----|---------|-------|-------|-------------|
| 1 | GeorgeMcIntyre-Web | SimPilot | 210719 | 548 | 82 | 1528.8 | R 1 146 600 |
| 2 | GeorgeMcIntyre-Web | kinetiCORE | 288977 | 1260 | 78 | 1495.2 | R 1 121 400 |
| 3 | Process-Simulation | CoreCubicS | 264687 | 386 | 60 | 1344.0 | R 1 008 000 |
| 4 | houseplantstore | theplantstore | 54576 | 149 | 74 | 1330.1 | R 997 575 |
| 5 | DesignEngineeringTool | DesignGroupAccelerator | 128925 | 100 | 49 | 1251.6 | R 938 700 |
| 6 | Process-Simulation | RaveRelicAddOLP | 159606 | 231 | 47 | 1234.8 | R 926 100 |
| 7 | Process-Simulation | CustomLineSimulation | 124631 | 6 | 41 | 1184.4 | R 888 300 |
| 8 | Process-Simulation | FordFanuc-PS-XML-s | 56816 | 159 | 48 | 1176.9 | R 882 675 |
| 9 | Allen-Bradley | LogixCodeGenerator | 1431282 | 26 | 40 | 1176.0 | R 882 000 |
| 10 | GeorgeMcIntyre-Web | aurora_invest_app | 38092 | 122 | 72 | 917.4 | R 688 050 |
| 11 | GeorgeMcIntyre-Web | fire-protection | 31734 | 60 | 72 | 764.5 | R 573 375 |
| 12 | Process-Simulation | CustomGeneralCls | 32395 | 169 | 49 | 675.9 | R 506 925 |
| 13 | Process-Simulation | CustomKawasaki | 29108 | 15 | 45 | 590.7 | R 443 025 |
| 14 | Process-Simulation | BMWButtons | 29434 | 8 | 42 | 585.5 | R 439 125 |
| 15 | Process-Simulation | FordFanucVOSS-NextGen | 30737 | 3 | 36 | 585.5 | R 439 125 |
| 16 | GeorgeMcIntyre-Web | SimTreeNav | 22811 | 133 | 72 | 549.0 | R 411 750 |
| 17 | GeorgeMcIntyre-Web | NitroAGI | 24227 | 25 | 61 | 546.6 | R 409 950 |
| 18 | GeorgeMcIntyre-Web | SimuPro-Industrial-Suite | 26533 | 11 | 46 | 542.7 | R 407 025 |
| 19 | Process-Simulation | CustomKawasaki_2020 | 25563 | 26 | 38 | 493.6 | R 370 200 |
| 20 | GeorgeMcIntyre-Web | urbane-jungle | 22184 | 37 | 46 | 453.8 | R 340 350 |

