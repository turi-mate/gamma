package hu.bme.mit.gamma.uppaal.backannotation

import java.util.Scanner
import java.util.logging.Level
import java.util.logging.Logger

class VerificationResultReader implements Runnable {
	
	Scanner scanner
	volatile boolean isCancelled = false
	Logger logger
	StringBuilder output
	
	new(Scanner scanner, boolean log, boolean storeOutput) {
		this.scanner = scanner;
		if (log) {
			this.logger = Logger.getLogger("GammaLogger")
		}
		if (storeOutput) {
			this.output = new StringBuilder
		}
	}
	
	override void run() {
		while (!isCancelled && scanner.hasNext) {
			val line = scanner.nextLine()
			if (logger !== null) {
				logger.log(Level.INFO, line)
			}
			if (output !== null) {
				output.append(line)
			}
		}
	}
	
	def void cancel() {
		this.isCancelled = true
	}
	
	def getOutput() {
		return output.toString
	}
	
}