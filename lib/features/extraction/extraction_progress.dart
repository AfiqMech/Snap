sealed class ExtractionProgress {
  const ExtractionProgress();
}

class Idle extends ExtractionProgress {
  const Idle();
}

class Analyzing extends ExtractionProgress {
  final String status;
  const Analyzing(this.status);
}

class Downloading extends ExtractionProgress {
  final double progress;
  final String status;
  final String eta;
  const Downloading(this.progress, this.status, {this.eta = ""});
}

class Success extends ExtractionProgress {
  final String outputPath;
  final List<String> savedPaths;
  const Success(this.outputPath, {this.savedPaths = const []});
}

class Error extends ExtractionProgress {
  final String message;
  const Error(this.message);
}
