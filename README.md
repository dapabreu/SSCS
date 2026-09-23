# SATERA Space-based Communication Simulator (SSCS)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2021a%2B-orange.svg)](https://www.mathworks.com/products/matlab.html)
[![Project](https://img.shields.io/badge/Project-SATERA-success.svg)](https://www.satera-sesar.eu/)

This repository contains the communication network simulators developed for the **SATERA** project (Space-based composite Ads-b and multilaTeration systEm validation thRough scalable simulAtions). 

## Overview
The Space Segment Communications Simulator (SSCS) is a discrete-event network simulator developed under Work Package 4 (WP4) of the SATERA project. 

The primary objective of the SSCS is to model a highly dynamic Non-Terrestrial Network (NTN) architecture comprising Inter-Satellite Links (ISL) and Downlinks (DL). The simulator evaluates critical network features, including end-to-end latency, packet loss rate (PLR), and overall communication network reliability, ensuring that time-critical measurements (such as Time of Arrival, Angle of Arrival, and Frequency of Arrival) reach the Central Processing Station (CPS) within the strict 500 ms network transit constraint required for accurate Multilateration (MLAT).

## Architecture and Design Principles
The simulator follows an Object-Oriented Programming (OOP) paradigm, structured into distinct, interconnected modules to ensure scalability and extensibility. The architecture is divided into three primary layers:

1. **Execution Layer:** A top-level driver script (`SATERA_simulator_v2.m`) initializes the simulation pipeline, handles memory-mapped position datasets for efficient parallelization, and manages checkpointing capabilities via `.mat` backup files.
2. **Simulation Core:** The execution object (`simulation_t`) governs the discrete-event model. It tracks the simulation progress using internal clocks and manages an event queue built upon highly optimized data structures.
3. **Communication Layer:** This layer models the physical and logical links. It continuously updates Line of Sight (LoS) visibility matrices, calculates propagation delays, determines link capacity based on Shannon's formula, and calculates the Bit Error Rate (BER) using Additive White Gaussian Noise (AWGN) channel models and Binary Phase Shift Keying (BPSK) modulation approximations.

## Event Hierarchy and Data Structures
To maintain near-instantaneous event scheduling in a dense LEO constellation, the SSCS avoids standard arrays and employs custom, highly optimized data structures:
* **Bucket Queue & Min Heap:** Event queues are managed using MATLAB `containers.Map` integrated with a min heap structure to ensure $O(\log N)$ or better complexity for insertions and deletions.
* **Circular Queues:** Used at ground stations to efficiently identify and discard duplicate broadcast messages.
* **Interval Objects:** Track component occupancy and buffer delays, determining accurate start and resolution times for processing and transmission (TX) events.

Events are instantiated from a generalized `base_event` class and branch into specific subclasses: `processing_event`, `broadcast_event`, `link_event`, `tx_event`, and `rx_event`.

## Implemented Routing Algorithms
The SSCS currently implements three routing algorithms, accessible via the algorithmic layer:

### 1. Shortest Path (Centralized)
A deterministic algorithm that relies on global network visibility. At each timestep, it constructs a directed graph from the adjacency matrix (representing TX and propagation delays) and utilizes MATLAB's `shortestpathtree` function to compute the optimal path from every satellite to the ground stations. It yields minimal end-to-end travel time but faces scalability challenges and relies heavily on centralized logic.

### 2. Adjacent's Path v1 (Distributed)
A decentralized, reactive routing protocol based on the principles of Link Congestion-Oriented RIP (LCO-RIP). Routing knowledge propagates through local exchanges of routing messages. 
* **Weight Function:** Routes are evaluated by balancing the remaining active time of the connection against the end-to-end delay ($W = \frac{RemainingTime}{1 + Delay}$). 
* It distributes workloads more evenly across the constellation but can suffer from packet drops before initial routes are fully flooded through the network.

### 3. Adjacent's Path v2 (Distributed, Dynamic Request)
An improvement over v1, this iteration actively requests new routes when old ones expire or when LoS connections are lost. 
* Employs distinct routing message types (Route Broadcast, Route Request, Route Response).
* **Weight Function:** Strictly prioritizes end-to-end delay ($W = \frac{1}{1 + Delay}$).
* Matches the delivery times of the centralized Shortest Path algorithm while maintaining a fully decentralized topology awareness.

## Configuration
Simulation parameters are decoupled from the codebase and defined in two external text files:
* **Link Data File:** Defines bandwidth, frequency, transmission power, TX/RX antenna gains, noise temperature, and modulation parameters.
* **Configuration Data File:** Specifies constants (e.g., speed of light, Earth's radius), runtime constraints, base times, output logging flags, component dimensions, and the active routing algorithms.

## License
This software is licensed under the **GNU General Public License v3.0 (GPLv3)**. 
You may copy, distribute, and modify the software as long as you track changes/dates in source files. Any modifications to the software, including GPL-licensed code (e.g., via a compiler), must also be made available under the GPL, along with build & install instructions. For more details, refer to the `LICENSE` file in this repository.

## Acknowledgments

This simulator was developed as part of the **SATERA** project. SATERA is funded by the **SESAR Joint Undertaking (JU)** and **Horizon Europe** under grant agreement No. 101164313. 

For more information about the project's milestones, deliverables, and publications, please visit the [official SATERA website](https://www.satera-sesar.eu/).
