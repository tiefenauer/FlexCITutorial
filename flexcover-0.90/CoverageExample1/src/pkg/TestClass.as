package pkg
{
    import mx.controls.Alert;
    
    public class TestClass
    {
        private static var counter:uint = 0;
        
        public function TestClass()
        {
        }
        
        public function testFunction(arg:Number):void
        {
            trace("TestClass.testFunction(", arg, ")");
            if (++counter >= 5)
            {
                Alert.show("Surprise!!!");
            }
        }
        
        public static function staticFunction():void
        {
            trace("TestClass.staticFunction");            
        }
    }
}