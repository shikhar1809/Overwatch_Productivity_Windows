# Overwatch Productivity Windows

Overwatch Productivity Windows is a robust, dynamic application designed to enforce strict focus and build unwavering discipline. It acts as an autonomous guardian against digital distractions. 

Built specifically for helping students focus more on **DSA (Data Structures and Algorithms)** and **college studies**—the two most important factors determining their placement success.

*Built by a B.Tech 2nd Year Student.*

---

## 🎯 Purpose and Vision
As a computer science student, breaking away from the dopamine loop of passive media to grind through Data Structures and Algorithms or conquer college coursework is the defining factor for placement success.

**Overwatch** is built on the philosophy of the "Locked Pattern." When a session is submitted, it engages strict app-blocking, distraction logging, continuous face-monitoring, and penalty-scoring. The rules cannot be changed arbitrarily without breaking the pattern explicitly. It holds you accountable when sheer willpower isn't enough.

## ✨ Core Features

*   **24-Hour Schedule Planner**: Visually plan your entire day via a drag-and-drop interactive timeline. Drop High-Priority (Red), Medium (Amber), or Low (Green) tasks directly into your hourly slots.
*   **Locked Daily Session**: Once the morning ritual is completed and tasks are committed, the day plan locks. No tasks can be removed or slotted tasks changed, enforcing unyielding dedication to the original intention.
*   **Face Monitor (MediaPipe/TFLite)**: The app detects immediately if you try to scroll on your phone while you are supposed to be focusing. It tracks your phone presence and logs violations automatically.
*   **OverWatch Block & Monitor Constraints**: Toggling the monitor forces strict focus mode. Need out? You'll have to manually acknowledge breaking the rule by strictly typing the override termination phrase.
*   **System Event Tracking**: Monitors active application windows to ensure you haven't strayed from your focus blocks (Requires admin capabilities for hard blocking).
*   **Night Score Processing**: Evaluates your performance across time slots against checkpoints, penalizing uncompleted 'Red' tasks severely to quantify your productivity grade each night.

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (Windows Setup)
* Built strictly for Windows environments.

### Local Development
To run this application locally from the source:
1. Ensure `flutter` is configured properly in your `PATH`.
2. Extract the relevant dependencies and run:
```bash
flutter pub get
```
3. Build the Windows executable:
```bash
flutter build windows
```
4. Start the application via the created executable located in `build/windows/x64/runner/Release/focus_os.exe`.

---
*“Break the loop now, or the pattern will continue tomorrow.”*
