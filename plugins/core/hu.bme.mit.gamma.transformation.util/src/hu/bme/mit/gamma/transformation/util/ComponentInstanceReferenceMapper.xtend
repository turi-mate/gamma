package hu.bme.mit.gamma.transformation.util

import hu.bme.mit.gamma.statechart.composite.ComponentInstanceReference
import hu.bme.mit.gamma.statechart.interface_.Component
import hu.bme.mit.gamma.util.GammaEcoreUtil
import org.eclipse.emf.ecore.EObject

class ComponentInstanceReferenceMapper {
	// Singleton
	public static final ComponentInstanceReferenceMapper INSTANCE = new ComponentInstanceReferenceMapper
	protected new() {}
	//
	protected final SimpleInstanceHandler simpleInstanceHandler = SimpleInstanceHandler.INSTANCE
	protected final extension GammaEcoreUtil ecoreUtil = GammaEcoreUtil.INSTANCE
	
	def getNewSimpleInstance(ComponentInstanceReference originalInstance, Component newTopComponent) {
		return simpleInstanceHandler.getNewSimpleInstance(originalInstance, newTopComponent)
	}
	
	def <T extends EObject> getNewObject(ComponentInstanceReference originalInstance,
			T originalObject, Component newTopComponent) {
		val newInstance = originalInstance.getNewSimpleInstance(newTopComponent)
		val newComponent = newInstance.type
		val contents = newComponent.getAllContentsOfType(originalObject.class)
		for (content : contents) {
			if (originalObject.helperEquals(content)) {
				return content as T
			}
		}
		throw new IllegalStateException("New object not found: " + originalObject)
	}
	
}