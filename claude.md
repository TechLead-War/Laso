# Laso AI System Instructions

## CRITICAL: THE VERIFICATION MANDATE 
You are an AI assisting with **Laso**, a privacy-first iOS health analytics app built with SwiftUI and SwiftData.
You are prone to hallucinations if you rely on your pre-trained memory. **You are strictly forbidden from guessing.**

Before you provide *any* fact, file path, code snippet, or architectural detail, you MUST complete this loop:
1. **Acknowledge the gap:** If you don't have the file currently open in your context, assume you do not know the answer.
2. **Use Tools First:** You MUST use your available tools (`read_file`, `grep`, or terminal commands) to fetch the source of truth from the codebase.
3. **Read Before Write:** Do not propose a code change until you have used tools to read the target file AND its surrounding dependencies (e.g., checking `AppContainer.swift` before injecting a dependency).

If you cannot verify a fact using tools, explicitly state: "I cannot verify this. I need you to run [command] or provide [context]."

## Architecture & Framework Invariants (Do Not Break)
* **State Management:** Use the `@Observable` macro EXCLUSIVELY. **Never use Combine or `ObservableObject`.**
* **Dependency Injection:** Manual, property-based composition via `App/AppContainer.swift`. **Never introduce DI containers or frameworks.**
* **Health Categories:** Valid `HealthCategory` cases are `heart`, `sleep`, `activity`, `body`, `respiratory`, `mindfulness`, `mobility`. **There is NO `.vitals` case. Never invent one.**
* **HealthKit:** Queries stay strictly inside `HealthKitManager` / `HealthDataStore`. Sync is incremental via `StoredSyncMetadata`.
* **UI/Logic Separation:** Business logic and HealthKit queries NEVER live in SwiftUI Views. ViewModels must be `@MainActor`.
* **Contracts:** Rely on `Config/ServiceProtocols.swift` and `Data/HealthKitMetricRegistry.swift`. Do not break these interfaces.

## Coding & Build Standards
* **Concurrency:** Use Swift structured concurrency (`async`/`await`, `TaskGroup`). No raw threads. `@MainActor` for UI/ViewModels.
* **Error Handling:** Use Swift `throws` / `Result`. **Never use force unwraps (`!`) or `fatalError`.**
* **Privacy / Security:** NEVER log decrypted health data, API keys, or PII. Use `EncryptedStore` for sensitive data.
* **Build System:** The project uses **XcodeGen**. If you add a new file, it must be reflected in `project.yml`. Do not attempt to manually edit `project.pbxproj`. Ignore SourceKit cross-file resolution noise.

## Output Format
When asked to implement a change or answer a technical question, format your response EXACTLY like this:

### 1. Verification Step
*(State exactly which files you read or grep searches you ran to verify your context. If you didn't use tools, explain why).*

### 2. The Plan
*(A concise bulleted list of what you are going to change, in which files, and why).*

### 3. Execution / Code
*(The verified Swift code. Keep it focused and follow the `@Observable` / `async/await` rules).*

### 4. Risks
*(Call out edge cases: e.g., HealthKit permission failures, missing data for ML models, partial SwiftData syncs, or MainActor isolation issues).*