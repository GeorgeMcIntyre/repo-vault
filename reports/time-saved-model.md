# Time-Saved Value (TSV) Model

**Generated:** 2026-01-31 21:22:14

## Methodology

The Time-Saved Value model estimates the economic value of time saved through automation, tooling, and process improvements.

### Calculation Formula

```
Base Hours Saved = f(Classification, LOC)
  - Production: min(2000, LOC / 20)
  - Tooling: min(1000, LOC / 30)
  - R&D: min(500, LOC / 50)

Automation Multiplier = f(Themes)
  - Virtual Commissioning: 3.0x
  - Simulation: 2.5x
  - DevOps: 2.0x
  - Robotics/PLC: 1.8x
  - Other: 1.0x

Quality Factor = 1.0 + bonuses
  - Has Tests: +0.3
  - High Activity (>100 commits): +0.2

Total Hours Saved = Base Hours Ã— Automation Multiplier Ã— Quality Factor
TSV (ZAR) = Total Hours Saved Ã— R750/hour
```

## Portfolio TSV Summary

- **Total Hours Saved:** 49 402 hours
- **Total TSV Value:** R 37 051 785
- **Average per Repository:** 425.9 hours (R 319 412)

### TSV by Classification

| Classification | Repos | Hours Saved | TSV Value (ZAR) | Avg per Repo |
|---------------|-------|-------------|-----------------|--------------|
| Production | 3 | 11 574 | R 8 680 650 | 3858.1 hrs |
| Tooling | 24 | 27 994 | R 20 995 275 | 1166.4 hrs |
| R&D | 89 | 9 835 | R 7 375 860 | 110.5 hrs |

## Top 20 Repositories by Time-Saved Value

| Rank | Repo | Classification | Themes | Hours Saved | TSV Value |
|------|------|----------------|--------|-------------|-----------|
| 1 | GeorgeMcIntyre-Web/SimPilot | Production | Simulation, Web-Tooling | 7500 | R 5 625 000 |
| 2 | Process-Simulation/AutoFactoryScope | Production | Virtual-Commissioning, Web-Tooling | 3240.9 | R 2 430 675 |
| 3 | GeorgeMcIntyre-Web/SimTreeNav | Tooling | Simulation | 2850 | R 2 137 500 |
| 4 | GeorgeMcIntyre-Web/SimuPro-Industrial-Suite | Tooling | Simulation, Web-Tooling | 2210 | R 1 657 500 |
| 5 | Process-Simulation/FordFanuc-PS-XML-s | Tooling | PLC-Controls, Robotics | 2160 | R 1 620 000 |
| 6 | Process-Simulation/RaveRelicAddOLP | Tooling | Robotics | 2160 | R 1 620 000 |
| 7 | Allen-Bradley/LogixCodeGenerator | Tooling | PLC-Controls | 1800 | R 1 350 000 |
| 8 | Process-Simulation/CustomKawasaki | Tooling | PLC-Controls, Robotics | 1746 | R 1 309 500 |
| 9 | GeorgeMcIntyre-Web/kinetiCORE | Tooling | Web-Tooling | 1500 | R 1 125 000 |
| 10 | GeorgeMcIntyre-Web/aurora_invest_app | Tooling | Web-Tooling | 1500 | R 1 125 000 |
| 11 | houseplantstore/theplantstore | Tooling | Web-Tooling | 1500 | R 1 125 000 |
| 12 | GeorgeMcIntyre-Web/fire-protection | Tooling | Web-Tooling | 1300 | R 975 000 |
| 13 | Process-Simulation/CustomLineSimulation | R&D | Simulation | 1250 | R 937 500 |
| 14 | Process-Simulation/CustomGeneralCls | Tooling | - | 1200 | R 900 000 |
| 15 | Process-Simulation/CoreCubicS | Tooling | - | 1200 | R 900 000 |
| 16 | Process-Simulation/CustomRoboticCls | Tooling | Robotics | 1094.4 | R 820 800 |
| 17 | GeorgeMcIntyre-Web/NitroAGI | Tooling | - | 1050.4 | R 787 800 |
| 18 | DesignEngineeringTool/DesignGroupAccelerator | Tooling | - | 1000 | R 750 000 |
| 19 | Process-Simulation/CustomKawasaki_2020 | R&D | PLC-Controls, Robotics | 900 | R 675 000 |
| 20 | Process-Simulation/FordFanucVOSS-NextGen | R&D | PLC-Controls, Robotics | 900 | R 675 000 |

## Automation Champions

Repositories with the highest automation multipliers (Virtual Commissioning & Simulation):

### GeorgeMcIntyre-Web/SimPilot
- **Hours Saved:** 7500
- **TSV Value:** R 5 625 000
- **Automation Type:** Simulation, Web-Tooling
- **Impact:** High-value automation reducing manual commissioning/simulation work

### Process-Simulation/AutoFactoryScope
- **Hours Saved:** 3240.9
- **TSV Value:** R 2 430 675
- **Automation Type:** Virtual-Commissioning, Web-Tooling
- **Impact:** High-value automation reducing manual commissioning/simulation work

### GeorgeMcIntyre-Web/SimTreeNav
- **Hours Saved:** 2850
- **TSV Value:** R 2 137 500
- **Automation Type:** Simulation
- **Impact:** High-value automation reducing manual commissioning/simulation work

### GeorgeMcIntyre-Web/SimuPro-Industrial-Suite
- **Hours Saved:** 2210
- **TSV Value:** R 1 657 500
- **Automation Type:** Simulation, Web-Tooling
- **Impact:** High-value automation reducing manual commissioning/simulation work

### Process-Simulation/CustomLineSimulation
- **Hours Saved:** 1250
- **TSV Value:** R 937 500
- **Automation Type:** Simulation
- **Impact:** High-value automation reducing manual commissioning/simulation work

### DesignEngineeringTool/AutoFactoryScope
- **Hours Saved:** 561.6
- **TSV Value:** R 421 200
- **Automation Type:** Virtual-Commissioning
- **Impact:** High-value automation reducing manual commissioning/simulation work

### Process-Simulation/SimChecker
- **Hours Saved:** 332.5
- **TSV Value:** R 249 375
- **Automation Type:** Simulation
- **Impact:** High-value automation reducing manual commissioning/simulation work

### Process-Simulation/SimulationPlayerViewer
- **Hours Saved:** 147.5
- **TSV Value:** R 110 625
- **Automation Type:** Simulation
- **Impact:** High-value automation reducing manual commissioning/simulation work

### Process-Simulation/DesignGroup.ProcessSimulate.Plugins
- **Hours Saved:** 0
- **TSV Value:** R 0
- **Automation Type:** Simulation
- **Impact:** High-value automation reducing manual commissioning/simulation work

