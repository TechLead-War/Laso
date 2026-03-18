import Foundation
import CoreML

/// Native Swift wrapper for Apple Neural Engine (ANE) Inference using CoreML.
/// Parses raw domain objects (DailyFeatureVector) into MLMultiArray tensors for inference.
final class CoreMLEngine {
    /// The compiled CoreML Model instance
    private var model: HealthStateModel?
    
    /// Flag indicating whether the Neural Network is available for faster/superior inference
    var isAvailable: Bool { model != nil }
    
    init() {
        loadModel()
    }
    
    private func loadModel() {
        // Attempt to load the dynamically generated model from bundle
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all // Allows ANE (Apple Neural Engine), GPU, or CPU
            
            // Note: In a real app, HealthStateModel.mlmodelc would be compiled into the app bundle.
            // For this R&D environment, we try to load it if available from the bundle.
            self.model = try HealthStateModel(configuration: config)
            print("[CoreMLEngine] Successfully loaded neural network inference model!")
        } catch {
            print("[CoreMLEngine] Warning: CoreML model not found or failed to load. Falling back to GMM clustering. Error: \(error)")
        }
    }
    
    // MARK: - Inference Pipeline
    
    enum CoreMLError: Error {
        case modelNotAvailable
        case invalidInputData
    }
    
    /// Execute a forward pass on the neural network
    func predictRisk(vector: DailyFeatureVector, orderedKeys: [FeatureKey]) throws -> Double {
        guard let model = model else { throw CoreMLError.modelNotAvailable }
        
        // 1. Feature Engineering
        let rawFeatures = vector.toArray(orderedKeys: orderedKeys)
        guard rawFeatures.count == 7 else { throw CoreMLError.invalidInputData }
        
        let hrv = rawFeatures[0]
        let rhr = rawFeatures[1]
        let sleep = rawFeatures[2]
        let deep = rawFeatures[3]
        let cals = rawFeatures[4]
        let steps = rawFeatures[5]
        let vo2 = rawFeatures[6]
        
        // 2. Structuring Input
        let input = HealthStateModelInput(
            hrv: hrv == FeatureKey.missingSentinel ? 0 : hrv,
            rhr: rhr == FeatureKey.missingSentinel ? 0 : rhr,
            sleepDuration: sleep == FeatureKey.missingSentinel ? 0 : sleep,
            deepSleep: deep == FeatureKey.missingSentinel ? 0 : deep,
            calories: cals == FeatureKey.missingSentinel ? 0 : cals,
            steps: steps == FeatureKey.missingSentinel ? 0 : steps,
            vo2max: vo2 == FeatureKey.missingSentinel ? 0 : vo2
        )
        
        // 3. Inference
        do {
            let prediction = try model.prediction(input: input)
            print("[CoreMLEngine] Inference Success: Risk = \(prediction.riskScore)")
            return prediction.riskScore
        } catch {
            throw error
        }
    }
    
    /// Batch inference for high-speed multi-day predictions utilizing ANE parallelization
    func predictBatch(vectors: [DailyFeatureVector], orderedKeys: [FeatureKey]) throws -> [Double] {
        guard let model = model else { throw CoreMLError.modelNotAvailable }
        guard #available(macOS 12.0, iOS 15.0, *) else {
            // Fallback to iterative if not supported
            return try vectors.map { try predictRisk(vector: $0, orderedKeys: orderedKeys) }
        }
        
        // Prepare batch provider
        var featureProviders: [MLFeatureProvider] = []
        
        for vector in vectors {
            let rawFeatures = vector.toArray(orderedKeys: orderedKeys)
            guard rawFeatures.count == 7 else { continue }
            
            let input = HealthStateModelInput(
                hrv: rawFeatures[0] == FeatureKey.missingSentinel ? 0 : rawFeatures[0],
                rhr: rawFeatures[1] == FeatureKey.missingSentinel ? 0 : rawFeatures[1],
                sleepDuration: rawFeatures[2] == FeatureKey.missingSentinel ? 0 : rawFeatures[2],
                deepSleep: rawFeatures[3] == FeatureKey.missingSentinel ? 0 : rawFeatures[3],
                calories: rawFeatures[4] == FeatureKey.missingSentinel ? 0 : rawFeatures[4],
                steps: rawFeatures[5] == FeatureKey.missingSentinel ? 0 : rawFeatures[5],
                vo2max: rawFeatures[6] == FeatureKey.missingSentinel ? 0 : rawFeatures[6]
            )
            featureProviders.append(input)
        }
        
        let batchProvider = MLArrayBatchProvider(array: featureProviders)
        
        // Execute Batch
        let batchResult = try model.predictions(fromBatch: batchProvider)
        
        // Parse Results
        var risks: [Double] = []
        for i in 0..<batchResult.count {
            if let output = batchResult.features(at: i).featureValue(for: "riskScore")?.doubleValue {
                risks.append(output)
            }
        }
        
        return risks
    }
}

// MARK: - Auto-Generated Model Definition Protocol
// This acts as a stub definition for the compiled MLModel to resolve against the Swift compiler locally.
import CoreML

@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class HealthStateModelInput : MLFeatureProvider {
    var hrv: Double
    var rhr: Double
    var sleepDuration: Double
    var deepSleep: Double
    var calories: Double
    var steps: Double
    var vo2max: Double
    
    var featureNames: Set<String> {
        get { return ["hrv", "rhr", "sleepDuration", "deepSleep", "calories", "steps", "vo2max"] }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "hrv" { return MLFeatureValue(double: hrv) }
        if featureName == "rhr" { return MLFeatureValue(double: rhr) }
        if featureName == "sleepDuration" { return MLFeatureValue(double: sleepDuration) }
        if featureName == "deepSleep" { return MLFeatureValue(double: deepSleep) }
        if featureName == "calories" { return MLFeatureValue(double: calories) }
        if featureName == "steps" { return MLFeatureValue(double: steps) }
        if featureName == "vo2max" { return MLFeatureValue(double: vo2max) }
        return nil
    }
    
    init(hrv: Double, rhr: Double, sleepDuration: Double, deepSleep: Double, calories: Double, steps: Double, vo2max: Double) {
        self.hrv = hrv
        self.rhr = rhr
        self.sleepDuration = sleepDuration
        self.deepSleep = deepSleep
        self.calories = calories
        self.steps = steps
        self.vo2max = vo2max
    }
}

@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class HealthStateModelOutput : MLFeatureProvider {
    let provider : MLFeatureProvider
    
    lazy var riskScore: Double = {
        return self.provider.featureValue(for: "riskScore")!.doubleValue
    }()
    
    var featureNames: Set<String> {
        return self.provider.featureNames
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return self.provider.featureValue(for: featureName)
    }
    
    init(riskScore: Double) {
        let dictionary : [String: Any] = ["riskScore": riskScore]
        self.provider = try! MLDictionaryFeatureProvider(dictionary: dictionary)
    }
    
    init(features: MLFeatureProvider) {
        self.provider = features
    }
}

@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class HealthStateModel {
    let model: MLModel
    
    init(model: MLModel) {
        self.model = model
    }
    
    convenience init(configuration: MLModelConfiguration) throws {
        // Find URL dynamically. 
        // We will mock load this for R&D purposes unless the package is bundled properly.
        class BundleClass {}
        guard let url = Bundle(for: BundleClass.self).url(forResource: "HealthStateModel", withExtension: "mlmodelc") else {
            throw NSError(domain: "CoreML", code: 1, userInfo: [NSLocalizedDescriptionKey : "Model file not found"])
        }
        let builtModel = try MLModel(contentsOf: url, configuration: configuration)
        self.init(model: builtModel)
    }
    
    func prediction(input: HealthStateModelInput) throws -> HealthStateModelOutput {
        return try self.prediction(input: input, options: MLPredictionOptions())
    }
    
    func prediction(input: HealthStateModelInput, options: MLPredictionOptions) throws -> HealthStateModelOutput {
        let outFeatures = try model.prediction(from: input, options: options)
        return HealthStateModelOutput(features: outFeatures)
    }
    
    func predictions(fromBatch batch: MLBatchProvider) throws -> MLBatchProvider {
        return try model.predictions(fromBatch: batch)
    }
}
