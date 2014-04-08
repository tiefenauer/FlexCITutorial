/* 
 * Copyright (c) 2008 Allurent, Inc.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify,
 * merge, publish, distribute, sublicense, and/or sell copies of the
 * Software, and to permit persons to whom the Software is furnished
 * to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
 * OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
package com.allurent.coverage.runtime
{
    import com.adobe.ac.util.service.IReceivingLocalConnection;
    import com.adobe.ac.util.service.ISendingLocalConnection;
    import com.adobe.ac.util.service.LocalConnectionWrapper;
    
    import flash.events.AsyncErrorEvent;
    import flash.events.ErrorEvent;
    import flash.events.SecurityErrorEvent;
    import flash.events.StatusEvent;
    import flash.events.TimerEvent;
    import flash.utils.Timer;
    
    /**
     * This class provides overall coverage recording support for an instrumented application
     * using a LocalConnection and its built-in serialization support for objects.
     */
    public class LocalConnectionCoverageAgent extends AbstractCoverageAgent
    {
        // default connection name
        private static const DEFAULT_CONNECTION_NAME:String = "_flexcover";
        // default connection name to ack received coverage data.
        private static const DEFAULT_ACK_CONNECTION_NAME:String = "_flexcover_ack";
        
        // handler function names on client end of LocalConnection
        private static const DATA_HANDLER:String = "coverageData";
        private static const DATA_EXIT_HANDLER:String = "coverageDataAndExit";
        
        // Maximum total key length allowed before forced LC send packet
        private static const MAX_SEND_LENGTH:uint = 10000;
        
        private var _assumeAck:uint = 100;
        private var _assumeAckTimer:Timer;
        
        /**
         * Obtain a flag indicating whether there are any outstanding send or exit operations. 
         */
        override public function get operationsPending():Boolean
        {
            return (pendingWrites > 0);
        }        
        
        /**
         * LocalConnection name to be used by coverage recording.  Must be modified
         * prior to first coverage output.
         */
        public var coverageDataConnectionName:String;        
        
        // LocalConnection used for writing coverage data
        private var coverageDataConnection:ISendingLocalConnection;
  
        // LocalConnection open for acknowleding received data from live instrumented apps
        private var ackConnection:IReceivingLocalConnection;        
        // LocalConnection name to receive ack and send more. We receive this from the viewer as
        //we want to support multiple agents serving one viewer.
        private var ackConnectionName:String;
        private var ackConnectionCounter:int;
        
        // counter of pending writes to local connection, important
        // in exiting the application only after all coverage data has been written
        private var pendingWrites:int = 0;
        
        //Array of coverage maps that need to be transfered to the coverage monitor. 
        //One hacky approach to ensure LocalConnetion doesn't crash due to too much data traffic.
        private var pendingMaps:Array = new Array();
        private var noPendingMaps:Boolean;            
        private var hasRegistrationBeenSent:Boolean; 
        //is allowed to send coverage data. Flag set from viewer in coverageReceived.
        private var canSend:Boolean;
        
        private var sequenceNumber:uint = 0;
        
        /**
         * Create a LocalConnectionCoverageAgent.
         * 
         * @param connectionName the name of the LocalConnection to be used.
         * 
         */
        public function LocalConnectionCoverageAgent(connectionName:String = null)
        {
            this.coverageDataConnectionName = (connectionName != null)
                ? connectionName
                : DEFAULT_CONNECTION_NAME;
        }
        
        /**
         * Flush all outstanding coverage data to this agent's destination.
         */
        override public function initializeAgent():void
        {
            coverageDataConnection = createCoverageDataConnection();
            coverageDataConnection.addEventListener(AsyncErrorEvent.ASYNC_ERROR, handleConnectionError);
            coverageDataConnection.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleConnectionError);
            coverageDataConnection.addEventListener(StatusEvent.STATUS, handleConnectionStatus);
            
            if(!hasRegistrationBeenSent)
            {
               sendRegistration();
               canSend = true;                 
            }
        }

        /**
         * Send a map of coverage keys and execution counts to this agent's destination.
         * @param map an Object whose keys are coverage elements and values are execution counts.
         */
        override public function sendCoverageMap(map:Object):Boolean
        {
        	//trace("LocalConnectionCoverageAgent.sendCoverageMap: " + map);
        	
            // Repeatedly accumulate MAX_SEND_LENGTH worth of coverage key/value
            // pairs in tempMap, sending over the LocalConnection as this limit
            // is reached.  This is a crude attempt to avoid exceeding the data size limit
            // inherent in LocalConnection.

            if (!canSend && !stopped)
            {
                return false;
            }

            var i:uint = 0;            
            var tempMap:Object = {};
            var foundSomething:Boolean;
            for (var key:String in map)
            {
            	foundSomething = true;
                tempMap[key] = map[key];
                
                if ((i += key.length) > MAX_SEND_LENGTH)
                {
                    addPendingMapAndAttemptSend(tempMap);
                    tempMap = {};
                    i = 0;
                }
            }
            
            // We might have some keys left over that didn't hit the max limit.
            if(foundSomething)
            {
                addPendingMapAndAttemptSend(tempMap);
            }
            
            return true;
        }
        
        public function coverageReceived(mapNumber:int):void
        {
            trace("LocalConnectionCoverageAgent.coverageReceived", mapNumber);
            resume();
        }

        private function handleAssumeAck(e:TimerEvent):void
        {
            trace("LocalConnectionCoverageAgent.assumeAck");
            resume();
        }        
        
        private function resume():void
        {
            if (_assumeAckTimer != null)
            {
                _assumeAckTimer.stop();
                _assumeAckTimer = null;
            }
            canSend = true;
            send();
        }
        
        protected function createCoverageDataConnection():ISendingLocalConnection
        {
            return new LocalConnectionWrapper();
        }
        
        protected function createAckConnection():IReceivingLocalConnection
        {
            return new LocalConnectionWrapper();
        }
        
        private function addPendingMapAndAttemptSend(map:Object):void
        {
            pendingMaps.push(map);
            trace("LocalConnectionCoverageAgent.addPendingMapAndAttempSend: " + pendingMaps.length);
            pendingWrites++;
            sequenceNumber++;
            
            if(canSend)
            {
            	send();
            }
        }
        
        private function traceKeys(map:Object):void
        {
            for (var key:String in map)
            {
                trace("LocalConnectionCoverageAgent.traceKeys: " + key);
            }        	
        }
        
        private function getACKConnectionName():String
        {
            ackConnectionCounter++;
            return DEFAULT_ACK_CONNECTION_NAME + ackConnectionCounter;
        }
                
        /**
         * Set up the LocalConnection that listens for the ack of received coverage data 
         * from an instrumented program. This will tell the sender to send more if required.
         */
        private function initializeACKConnection():void
        {
            if (ackConnection != null)
            {
                // Don't set this up multiple times.
                return;
            }
            
            trace("LocalConnectionCoverageAgent.initializeACKConnection: ackConnectionName " + ackConnectionName); 
            
            // Set up our LocalConnection.  Note that the Controller handles
            ackConnection = createAckConnection();
            ackConnection.allowDomain("*");
            ackConnection.client = this;
            
            try
            {
                var name:String = getACKConnectionName();
                ackConnection.connect(name);
            }
            catch (error:ArgumentError)
            {
                if (error.errorID == 2082)
                {
                    trace("LocalConnectionCoverageAgent - Coverage Registration Error. Another program has already opened a LocalConnection with id '"
                                + name + "'. Try another connection name...");
                                
                                
                    ackConnection = null;
                    initializeACKConnection();         
                }
                else
                { 
                    trace("LocalConnectionCoverageAgent - Coverage Registration Error. " + error.message);
                    ackConnection = null;
                }
            }
            this.ackConnectionName = ackConnectionName;
        }
        
        private function send():void
        {
           if(pendingMaps.length > 0)
           {
             sendMaps(pendingMaps);
             canSend = false;
           }
           else
           {
             trace("LocalConnectionCoverageAgent.sendMaps: Nothing to send ");
           }
        }
        
        private function sendMaps(maps:Array):void
        {
            var map:Object = maps.shift();
            var mapNumber:int = sequenceNumber - pendingMaps.length;
            //traceKeys(map);
            trace("LocalConnectionCoverageAgent.sendMaps: sent:", mapNumber, "remaining:" + pendingMaps.length);
            attemptLCSend(map, mapNumber);
        }
        
        private function sendRegistration():void
        {
        	initializeACKConnection();
            coverageDataConnection.send(coverageDataConnectionName, DATA_HANDLER, null, 0);
            hasRegistrationBeenSent = true;
        }
        
        private function attemptLCSend(map:Object, mapNumber:int):void
        {
	        try
	        {
	            var method:String = (stopped && pendingWrites == 1) ? DATA_EXIT_HANDLER : DATA_HANDLER;
	            trace("Using method", method);
                coverageDataConnection.send(coverageDataConnectionName, method, map, mapNumber);
                if (_assumeAckTimer != null)
                {
                    _assumeAckTimer.stop();
                }
                if (_assumeAck > 0)
                {
                    _assumeAckTimer = new Timer(_assumeAck, 1);
                    _assumeAckTimer.addEventListener(TimerEvent.TIMER, handleAssumeAck);
                    _assumeAckTimer.start();
                }
                pendingWrites--;
	        }
	        catch (error:Error)
	        {
	        	pendingWrites++;
                trace("LocalConnectionCoverageAgent - Coverage Recording Error. " + error.message);
	        }	
        }
        
        private function handleConnectionError(e:ErrorEvent):void
        {
            trace(e.text);
        }
        
        private function handleConnectionStatus(e:StatusEvent):void
        {
            if (e.level == "error")
            {
                // Something went awry.
                // TODO: This may write more data to the log than was actually lost,
                //    but the assumption for now is that the LC either works all the time or
                //    fails all the time.
                //
                broken = true;
            }
            trace("handleConnectionStatus pendingWrites " + pendingWrites );
            checkForExit();
        }
    }
}
