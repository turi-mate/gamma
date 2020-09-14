package hu.bme.mit.gamma.transformation.util

import hu.bme.mit.gamma.action.model.ActionModelFactory
import hu.bme.mit.gamma.expression.model.ExpressionModelFactory
import hu.bme.mit.gamma.expression.model.ParameterDeclaration
import hu.bme.mit.gamma.expression.model.VariableDeclaration
import hu.bme.mit.gamma.statechart.composite.SynchronousComponentInstance
import hu.bme.mit.gamma.statechart.interface_.Event
import hu.bme.mit.gamma.statechart.interface_.InterfaceModelFactory
import hu.bme.mit.gamma.statechart.interface_.Package
import hu.bme.mit.gamma.statechart.interface_.Port
import hu.bme.mit.gamma.statechart.statechart.EntryState
import hu.bme.mit.gamma.statechart.statechart.RaiseEventAction
import hu.bme.mit.gamma.statechart.statechart.StatechartDefinition
import hu.bme.mit.gamma.statechart.statechart.Transition
import hu.bme.mit.gamma.transformation.util.queries.RaiseInstanceEvents
import java.math.BigInteger
import java.util.AbstractMap.SimpleEntry
import java.util.Collection
import java.util.List
import java.util.Map
import java.util.Map.Entry
import java.util.Set
import org.eclipse.viatra.query.runtime.api.ViatraQueryEngine
import org.eclipse.viatra.query.runtime.emf.EMFScope

import static extension hu.bme.mit.gamma.statechart.derivedfeatures.StatechartModelDerivedFeatures.*

class GammaStatechartAnnotator {
	protected final Package gammaPackage
	protected final ViatraQueryEngine engine
	// Transition coverage
	protected boolean TRANSITION_COVERAGE
	protected final Set<SynchronousComponentInstance> transitionCoverableComponents = newHashSet
	protected final Set<Transition> coverableTransitions = newHashSet
	protected final Map<Transition, VariableDeclaration> transitionVariables = newHashMap // Boolean variables
	// Interaction coverage
	protected boolean INTERACTION_COVERAGE
	protected final Set<SynchronousComponentInstance> interactionCoverableComponents = newHashSet
	protected final Set<ParameterDeclaration> newParameters = newHashSet
	protected long senderId = 0
	protected long recevierId = 0
	protected final Map<RaiseEventAction, Long> sendingIds = newHashMap
	protected final Map<Transition, Long> receivingIds = newHashMap
	protected final Map<Transition, List<Entry<Port, Event>>> receivingInteractions = newHashMap // Check: list must be unique
	protected final Map<SynchronousComponentInstance,
		List<Pair<VariableDeclaration /*sender*/, VariableDeclaration /*receiver*/>>> interactionVariables = newHashMap // Check: list must be unique
	protected final Map<Entry<RaiseEventAction, Transition> /*interaction*/,
		Entry<Entry<VariableDeclaration, Long> /*sender*/,
		Entry<VariableDeclaration, Long> /*receier*/>> interactions = newHashMap
	// Resetable variables
	protected final Set<VariableDeclaration> resetableVariables = newHashSet
	// Factories
	protected final extension ExpressionModelFactory expressionModelFactory = ExpressionModelFactory.eINSTANCE
	protected final extension ActionModelFactory actionModelFactory = ActionModelFactory.eINSTANCE
	protected final extension InterfaceModelFactory interfaceModelFactory = InterfaceModelFactory.eINSTANCE
	// Namings
	protected final AnnotationNamings annotationNamings = new AnnotationNamings // Instance due to the id
	
	new(Package gammaPackage,
			Collection<SynchronousComponentInstance> transitionCoverableComponents,
			Collection<SynchronousComponentInstance> interactionCoverableComponents) {
		this.gammaPackage = gammaPackage
		this.engine = ViatraQueryEngine.on(new EMFScope(gammaPackage.eResource.resourceSet))
		if (!transitionCoverableComponents.empty) {
			this.TRANSITION_COVERAGE = true
			this.transitionCoverableComponents += transitionCoverableComponents
			this.coverableTransitions += transitionCoverableComponents
				.map[it.type].filter(StatechartDefinition)
				.map[it.transitions].flatten
		}
		if (!interactionCoverableComponents.empty) {
			this.INTERACTION_COVERAGE = true
			this.interactionCoverableComponents += interactionCoverableComponents
		}
	}
	
	// Transition coverage
	
	protected def needsAnnotation(Transition transition) {
		return !(transition.sourceState instanceof EntryState) &&
			coverableTransitions.contains(transition)
	}
	
	protected def createTransitionVariable(Transition transition) {
		val statechart = transition.containingStatechart
		val variable = createVariableDeclaration => [
			it.type = createBooleanTypeDefinition
			it.name = annotationNamings.getVariableName(transition)
		]
		statechart.variableDeclarations += variable
		transitionVariables.put(transition, variable)
		resetableVariables += variable 
		return variable
	}
	
	def annotateModelForTransitionCoverage() {
		if (!TRANSITION_COVERAGE) {
			return
		}
		// Annotating the transitions
		for (transition : coverableTransitions.filter[it.needsAnnotation]) {
			val variable = transition.createTransitionVariable
			val assignment = createAssignmentStatement => [
				it.lhs = createDirectReferenceExpression => [
					it.declaration = variable
				]
				it.rhs = createTrueExpression
			]
			transition.effects += assignment
		}
	}
	
	def getTransitionVariables() {
		return this.transitionVariables
	}
	
	// Interaction coverage
	
	protected def createInteractionVariables(SynchronousComponentInstance instance) {
		val statechart = instance.type as StatechartDefinition
		val senderVariable = createVariableDeclaration => [
			it.type = createIntegerTypeDefinition
			it.name = annotationNamings.getSendingVariableName(instance)
		]
		val receiverVariable = createVariableDeclaration => [
			it.type = createIntegerTypeDefinition
			it.name = annotationNamings.getReceivingVariableName(instance)
		]
		val variablePair = new Pair(senderVariable, receiverVariable)
		statechart.variableDeclarations += senderVariable
		statechart.variableDeclarations += receiverVariable
		if (!interactionVariables.containsKey(instance)) {
			interactionVariables.put(instance, newArrayList)
		}
		val interactionVariablesSet = interactionVariables.get(instance)
		interactionVariablesSet += variablePair
		resetableVariables += senderVariable
		resetableVariables += receiverVariable
		return variablePair
	}
	
	protected def getInteractionVariables(Transition transition, Port port, Event event) {
		val interactions = receivingInteractions.get(transition)
		val index = interactions.indexOf(new SimpleEntry(port, event)) // The i. interaction is saved using the i. variable
		val statechart = transition.containingStatechart
		val instance = statechart.referencingComponentInstance
		val variables = interactionVariables.get(instance)
		return variables.get(index)
	}
	
	protected def getSendingId(RaiseEventAction action) {
		if (!sendingIds.containsKey(action)) {
			sendingIds.put(action, senderId++)
		}
		return sendingIds.get(action)
	}
	
	protected def getReceivingId(Transition transition) {
		if (!receivingIds.containsKey(transition)) {
			receivingIds.put(transition, recevierId++)
		}
		return receivingIds.get(transition)
	}
	
	protected def putReceivingInteraction(Transition transition, Port port, Event event) {
		if (!receivingInteractions.containsKey(transition)) {
			receivingInteractions.put(transition, newArrayList)
		}
		val interactions = receivingInteractions.get(transition)
		interactions += new SimpleEntry(port, event)
	}
	
	def annotateModelForInteractionCoverage() {
		if (!INTERACTION_COVERAGE) {
			return
		}
		val sendingComponents = newHashSet
		val receivingComponents = newHashSet
		sendingComponents += interactionCoverableComponents
		receivingComponents += interactionCoverableComponents
		val interactionMatcher = RaiseInstanceEvents.Matcher.on(engine)
		sendingComponents.retainAll(interactionMatcher.allValuesOfoutInstance)
		receivingComponents.retainAll(interactionMatcher.allValuesOfinInstance)
		// Creating event parameters
		for (event : interactionMatcher.allValuesOfraisedEvent) {
			val newParameter = createParameterDeclaration => [
				it.type = createIntegerTypeDefinition
				it.name = annotationNamings.getParameterName(event)
			]
			event.parameterDeclarations += newParameter
			newParameters += newParameter
		}
		// Creating interaction variables - at least one pair is needed for every instance
		for (receivingComponent : receivingComponents) {
			receivingComponent.createInteractionVariables
		}
		// Annotating transitions
		for (match : interactionMatcher.allMatches
				.filter[interactionCoverableComponents.contains(it.outInstance) &&
					interactionCoverableComponents.contains(it.inInstance)]) {
			// Sending
			val raiseEventAction = match.raiseEventAction
			if (!sendingIds.containsKey(raiseEventAction)) {
				// One raise event action can synchronize to multiple transitions (broadcast channel)
				raiseEventAction.arguments += createIntegerLiteralExpression => 
					[it.value = BigInteger.valueOf(raiseEventAction.sendingId)]
			}
			// Receiving
			val inPort = match.inPort
			val event = match.raisedEvent
			val inParameter = event.parameterDeclarations.last // It is always the last
			val receivingTransition = match.receivingTransition
			val inInstance = match.inInstance
			if (!receivingInteractions.containsKey(receivingTransition)) {
				receivingInteractions.put(receivingTransition, newArrayList)
			}
			val interactionVariablesList = interactionVariables.get(inInstance)
			val receivingInteractions = receivingInteractions.get(receivingTransition)
			// We do not want to duplicate the same assignments
			if (!receivingInteractions.contains(new SimpleEntry(inPort, event))) {
				receivingTransition.putReceivingInteraction(inPort, event)
				if (interactionVariablesList.size < receivingInteractions.size) {
					// The difference can be at most one due to the algorithm
					inInstance.createInteractionVariables
				}
				val interactionVariables = receivingTransition.getInteractionVariables(inPort, event)
				val senderVariable = interactionVariables.key
				val receiverVariable = interactionVariables.value
				// Sender assignment
				receivingTransition.effects += createAssignmentStatement => [
					it.lhs = createDirectReferenceExpression => [
						it.declaration = senderVariable
					]
					it.rhs = createEventParameterReferenceExpression => [
						it.port = inPort
						it.event = event
						it.parameter = inParameter
					]
				]
				// Receiver assignment
				receivingTransition.effects += createAssignmentStatement => [
					it.lhs = createDirectReferenceExpression => [
						it.declaration = receiverVariable
					]
					it.rhs = createIntegerLiteralExpression => [
						it.value = BigInteger.valueOf(receivingTransition.receivingId)
					]
				]
			}
			val variables = receivingTransition.getInteractionVariables(inPort, event)
			val senderVariable = variables.key
			val receiverVariable = variables.value
			interactions.put(new SimpleEntry(raiseEventAction, receivingTransition),
				new SimpleEntry(new SimpleEntry(senderVariable, raiseEventAction.sendingId),
					new SimpleEntry(receiverVariable, receivingTransition.receivingId)
				)
			)
		}
	}
	
	def getNewParameters() {
		return this.newParameters
	}
	
	def getInteractions() {
		return this.interactions
	}
	
	def annotateModel() {
		annotateModelForTransitionCoverage
		annotateModelForInteractionCoverage
	}
	
}

class AnnotationNamings {
	
	public static val PREFIX = "__testAnnotation"
	public static val POSTFIX = "__"
	
	int id = 0
	
	def String getVariableName(Transition transition) '''�PREFIX��transition.sourceState.name�_�id++�_�transition.targetState.name��POSTFIX�'''
	def String getReceivingVariableName(SynchronousComponentInstance instance) '''�PREFIX�_rec_�instance.name��id++��POSTFIX�'''
	def String getSendingVariableName(SynchronousComponentInstance instance) '''�PREFIX�_send_�instance.name��id++��POSTFIX�'''
	def String getParameterName(Event event) '''�PREFIX��event.name��POSTFIX�'''
	
}