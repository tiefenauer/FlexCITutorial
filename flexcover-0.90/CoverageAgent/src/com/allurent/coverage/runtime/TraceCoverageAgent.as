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
    /**
     * This class provides trace-log-based coverage recording support
     * for an instrumented application.
     */
    public class TraceCoverageAgent extends AbstractCoverageAgent
    {
        public static const COVERAGE_TRACE_PREFIX:String = "__coverage__";

        /**
         * Send a map of coverage keys and execution counts to this agent's destination.
         * @param map an Object whose keys are coverage elements and values are execution counts.
         */
        override public function sendCoverageMap(map:Object):Boolean
        {
            for (var key:String in map)
            {
                trace(COVERAGE_TRACE_PREFIX, key, map[key]);
            }
            return true;
        }
    }
}
