/*
 * Copyright (c) 2009 the original author or authors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

package org.robotlegs.base
{
	import flash.events.Event;
	import flash.events.IEventDispatcher;
	import flash.utils.describeType;
	import flash.utils.Dictionary;
	
	import org.robotlegs.core.IInjector;
	import org.robotlegs.core.ICommandMap;
	import org.robotlegs.core.IReflector;
	
	/**
	 * An abstract <code>ICommandMap</code> implementation
	 */
	public class CommandMap implements ICommandMap
	{
		/**
		 * The <code>IEventDispatcher</code> to listen to
		 */
		protected var eventDispatcher:IEventDispatcher;
		
		/**
		 * The <code>IInjector</code> to inject with
		 */
		protected var injector:IInjector;
		
		/**
		 * The <code>IReflector</code> to reflect with
		 */
		protected var reflector:IReflector;
		
		/**
		 * Internal
		 *
		 * TODO: This needs to be documented
		 */
		protected var eventTypeMap:Dictionary;
		/**
		 * Internal
		 *
		 * Collection of command classes that have been verified to implement an <code>execute</code> method
		 */
		protected var verifiedCommandClasses:Dictionary;
		
		//---------------------------------------------------------------------
		//  Constructor
		//---------------------------------------------------------------------
		
		/**
		 * Creates a new <code>CommandMap</code> object
		 *
		 * @param eventDispatcher The <code>IEventDispatcher</code> to listen to
		 * @param injector An <code>IInjector</code> to use for this context
		 * @param reflector An <code>IReflector</code> to use for this context
		 */
		public function CommandMap(eventDispatcher:IEventDispatcher, injector:IInjector, reflector:IReflector)
		{
			this.eventDispatcher = eventDispatcher;
			this.injector = injector;
			this.reflector = reflector;
			this.eventTypeMap = new Dictionary(false);
			this.verifiedCommandClasses = new Dictionary(false);
		}
		
		//---------------------------------------------------------------------
		//  API
		//---------------------------------------------------------------------
		
		/**
		 * @inheritDoc
		 */
		public function mapEvent(eventType:String, commandClass:Class, eventClass:Class = null, oneshot:Boolean = false):void
		{
			if (!verifiedCommandClasses[commandClass])
			{
				verifiedCommandClasses[commandClass] = describeType(commandClass).factory.method.(@name == "execute").length() == 1;
				if (!verifiedCommandClasses[commandClass])
				{
					throw new ContextError(ContextError.E_COMMANDMAP_NOIMPL + ' - ' + commandClass);
				}
			}
			eventClass = eventClass || Event;
			
			var eventClassMap:Dictionary = eventTypeMap[eventType]
				|| (eventTypeMap[eventType] = new Dictionary(false));
				
			var callbacksByCommandClass:Dictionary = eventClassMap[eventClass]
				|| (eventClassMap[eventClass] = new Dictionary(false));
				
			if (callbacksByCommandClass[commandClass] != null)
			{
				throw new ContextError(ContextError.E_COMMANDMAP_OVR + ' - eventType (' + eventType + ') and Command (' + commandClass + ')');
			}
			var callback:Function = function(event:Event):void
			{
				routeEventToCommand(event, commandClass, oneshot, eventClass);
			};
			eventDispatcher.addEventListener(eventType, callback, false, 0, true);
			callbacksByCommandClass[commandClass] = callback;
		}
		
		/**
		 * @inheritDoc
		 */
		public function unmapEvent(eventType:String, commandClass:Class, eventClass:Class = null):void
		{
			var eventClassMap:Dictionary = eventTypeMap[eventType];
			if (eventClassMap == null) return;
			var callbacksByCommandClass:Dictionary = eventClassMap[eventClass || Event];
			if (callbacksByCommandClass == null) return;
			var callback:Function = callbacksByCommandClass[commandClass];
			if (callback == null) return;
			
			eventDispatcher.removeEventListener(eventType, callback, false);
			delete callbacksByCommandClass[commandClass];
		}
		
		/**
		 * @inheritDoc
		 */
		public function hasEventCommand(eventType:String, commandClass:Class, eventClass:Class = null):Boolean
		{
			var eventClassMap:Dictionary = eventTypeMap[eventType];
			if (eventClassMap == null) return false;
			var callbacksByCommandClass:Dictionary = eventClassMap[eventClass || Event];
			if (callbacksByCommandClass == null) return false;
			
			return callbacksByCommandClass[commandClass] != null;
		}
		
		//---------------------------------------------------------------------
		//  Internal
		//---------------------------------------------------------------------
		
		/**
		 * Event Handler
		 *
		 * @param event The <code>Event</code>
		 * @param commandClass The Class to construct and execute
		 * @param oneshot Should this command mapping be removed after execution?
		 */
		protected function routeEventToCommand(event:Event, commandClass:Class, oneshot:Boolean, originalEventClass:Class):void
		{
			var eventClass:Class = Object(event).constructor;
			if (!(event is originalEventClass)) return;
			injector.mapValue(eventClass, event);
			var command:Object = injector.instantiate(commandClass);
			injector.unmap(eventClass);
			command.execute();
			if (oneshot)
			{
				unmapEvent(event.type, commandClass, originalEventClass);
			}
		}
	
	}
}
