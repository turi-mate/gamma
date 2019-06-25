package hu.bme.mit.gamma.yakindu.transformation.commandhandler.taskhandler;

import static com.google.common.base.Preconditions.checkArgument;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl;

import hu.bme.mit.gamma.codegenerator.java.GlueCodeGenerator;
import hu.bme.mit.gamma.statechart.model.Component;
import hu.bme.mit.gamma.statechart.model.composite.ComponentInstance;
import hu.bme.mit.gamma.statechart.model.composite.CompositeComponent;
import hu.bme.mit.gamma.statechart.model.derivedfeatures.StatechartModelDerivedFeatures;
import hu.bme.mit.gamma.yakindu.genmodel.CodeGeneration;
import hu.bme.mit.gamma.yakindu.genmodel.ProgrammingLanguage;

public class CodeGenerationHandler extends TaskHandler {

	public void execute(CodeGeneration codeGeneration, String packageName) {
		checkArgument(codeGeneration.getLanguage().size() == 1, 
				"A single programming language must be specified: " + codeGeneration.getLanguage());
		checkArgument(codeGeneration.getLanguage().get(0) == ProgrammingLanguage.JAVA, 
				"Currently only Java is supported.");
		setCodeGeneration(codeGeneration, packageName);
		Component component = codeGeneration.getComponent();
		ResourceSet codeGenerationResourceSet = new ResourceSetImpl();
		codeGenerationResourceSet.getResource(component.eResource().getURI(), true);
		loadStatechartTraces(codeGenerationResourceSet, component);
		// The presence of the top level component and statechart traces are sufficient in the resource set
		// Contained composite components are automatically resolved by VIATRA
		GlueCodeGenerator generator = new GlueCodeGenerator(codeGenerationResourceSet,
				codeGeneration.getPackageName().get(0), targetFolderUri);
		generator.execute();
		generator.dispose();
	}
	
	private void setCodeGeneration(CodeGeneration codeGeneration, String packageName) {
		checkArgument(codeGeneration.getPackageName().size() <= 1);
		if (codeGeneration.getPackageName().isEmpty()) {
			codeGeneration.getPackageName().add(packageName);
		}
		// TargetFolder set in setTargetFolder
	}
	
	private void loadStatechartTraces(ResourceSet resourceSet, Component component) {
		if (component instanceof CompositeComponent) {
			CompositeComponent compositeComponent = (CompositeComponent) component;
			for (ComponentInstance containedComponent : StatechartModelDerivedFeatures.getDerivedComponents(compositeComponent)) {
				loadStatechartTraces(resourceSet, StatechartModelDerivedFeatures.getDerivedType(containedComponent));
			}
		}
		else {
			// E.g., /hu.bme.mit.gamma.tutorial.extra/model/TrafficLight/TrafficLightCtrl
			String statechartUri = component.eResource().getURI().trimFileExtension().toPlatformString(true);
			String statechartFileName = statechartUri.substring(statechartUri.lastIndexOf("/") + 1);
			String traceUri = statechartUri.substring(0, statechartUri.lastIndexOf("/") + 1) + "." + statechartFileName + ".y2g";
			if (resourceSet.getResources().stream().noneMatch(it -> it.getURI().toString().equals(traceUri))) {
				resourceSet.getResource(URI.createPlatformResourceURI(traceUri, true), true);
			}
		}
	}

}
