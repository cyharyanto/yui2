package
{
	import flash.display.Sprite;
	import flash.display.DisplayObject;
	import flash.events.ErrorEvent;
	import flash.external.ExternalInterface;
	import flash.system.LoaderContext;
	import flash.text.TextFormat;
	import flash.utils.getQualifiedClassName;
	import fl.managers.StyleManager;
	import com.yahoo.astra.fl.charts.*;
	import com.yahoo.astra.fl.charts.series.*;
	import com.yahoo.astra.fl.charts.skins.*;
	import com.yahoo.astra.fl.charts.events.ChartEvent;
	import com.yahoo.astra.utils.JavaScriptUtil;
	import com.yahoo.astra.utils.LoaderUtil;
	import com.yahoo.yui.YUIAdapter;
	import com.yahoo.yui.LoggerCategory;
	import com.yahoo.yui.charts.*;

	[SWF(backgroundColor=0xffffff)]
	/**
	 * A wrapper for the Astra Charts components to allow them to be used by the YUI library.
	 * 
	 * @author Josh Tynjala
	 */
	public class Charts extends YUIAdapter
	{
		
	//--------------------------------------
	//  Constructor
	//--------------------------------------
	
		/**
		 * Constructor.
		 */
		public function Charts()
		{
			super();
		}
		
	//--------------------------------------
	//  Properties
	//--------------------------------------
	
		/**
		 * @private (protected)
		 * A reference to the chart instance.
		 */
		protected var chart:Chart;
		
		/**
		 * @private (protected)
		 */
		protected var background:BackgroundAndBorder;
		
		/**
		 * @private
		 */
		override protected function get component():DisplayObject
		{
			//why do I have to do this? it's not ambiguous!
			return super.component;
		}
		
		/**
		 * @private
		 */
		override protected function set component(value:DisplayObject):void
		{
			this.chart = Chart(value);
			super.component = value;
		}
		
	//--------------------------------------
	//  Public Methods
	//--------------------------------------
		
		/**
		 * Creates a chart instance based on the specified type.
		 */
		public function setType(value:String):void
		{
			if(this.chart)
			{
				this.removeChild(this.chart);
				this.chart.removeEventListener(ChartEvent.ITEM_CLICK, chartItemEventHandler);
				this.chart.removeEventListener(ChartEvent.ITEM_DOUBLE_CLICK, chartItemEventHandler);
				this.chart.removeEventListener(ChartEvent.ITEM_ROLL_OUT, chartItemEventHandler);
				this.chart.removeEventListener(ChartEvent.ITEM_ROLL_OVER, chartItemEventHandler);
			}
			
			var ChartType:Class = ChartSerializer.getType(value);
			var chart:Chart = new ChartType();
			chart.setStyle("backgroundSkin", Sprite);
			chart.setStyle("dataTipBackgroundSkin", ChartDataTipBackground);
			this.addChild(chart);
			
			this.component = chart;
			this.chart.addEventListener(ChartEvent.ITEM_CLICK, chartItemEventHandler, false, 0, true);
			this.chart.addEventListener(ChartEvent.ITEM_DOUBLE_CLICK, chartItemEventHandler, false, 0, true);
			this.chart.addEventListener(ChartEvent.ITEM_ROLL_OUT, chartItemEventHandler, false, 0, true);
			this.chart.addEventListener(ChartEvent.ITEM_ROLL_OVER, chartItemEventHandler, false, 0, true);
			
			this.log("Type set to \"" + value + "\"");
		}
		
		public function setDataProvider(value:Array):void
		{
			var dataProvider:Array = [];
			var seriesCount:int = value.length;
			
			//will be filled based on the defaults or the series style definition, if present.
			var seriesColors:Array = [];
			var seriesMarkerSizes:Array = [];
			var seriesMarkerSkins:Array = [];
			
			for(var i:int = 0; i < seriesCount; i++)
			{
				var dataFromJavaScript:Object = value[i];
				var currentData:ISeries = this.chart.dataProvider[i] as ISeries;
				var seriesType:Class = SeriesSerializer.shortNameToSeriesType(dataFromJavaScript.type);
				var series:ISeries;
				if(currentData is seriesType)
				{
					//reuse the series if possible because we want animation
					series = SeriesSerializer.readSeries(dataFromJavaScript, currentData);
				}
				else
				{
					series = SeriesSerializer.readSeries(dataFromJavaScript);
				}
				dataProvider[i] = series;
			
				//defaults
				var defaultColors:Array = [0x729fcf, 0xfcaf3e, 0x73d216, 0xfce94f, 0xad7fa8, 0x3465a4];
				var defaultSize:Number = 10;
				if(series is ColumnSeries || series is BarSeries)
				{
					defaultSize = 20;
				}
				
				var defaultSkin:Class = RectangleSkin;
				if(series is LineSeries)
				{
					defaultSkin = CircleSkin;
				}
				
				//initialize styles with defaults
				var size:Number = defaultSize;
				var color:uint = defaultColors[i % defaultColors.length];
				var skin:Object = defaultSkin;
				var style:Object = dataFromJavaScript.style;
				if(style)
				{
					if(style.image)
					{
						skin = LoaderUtil.createAutoLoader(skin.image, new LoaderContext(true));
					}
					if(style.size != null)
					{
						size = style.size;
					}
					if(style.color != null)
					{
						color = style.color;
					}
				}
				
				seriesColors[i] = color;
				seriesMarkerSizes[i] = size;
				seriesMarkerSkins[i] = skin;
			}
			
			//set data provider and new styles
			this.chart.dataProvider = dataProvider;
			this.chart.setStyle("seriesColors", seriesColors);
			this.chart.setStyle("seriesMarkerSizes", seriesMarkerSizes);
			this.chart.setStyle("seriesMarkerSkins", seriesMarkerSkins);
		}
		
		/**
		 * Returns the category names.
		 */
		public function getCategoryNames():Array
		{
			var categoryChart:ICategoryChart = this.chart as ICategoryChart;
			if(categoryChart)
			{
				return categoryChart.categoryNames;
			}
			var shortName:String = ChartSerializer.getShortName(getQualifiedClassName(this.chart));
			this.log("Cannot find categoryNames on a chart of type " + shortName);
			return null;
		}
		
		/**
		 * Sets the category names used if the data requires a category axis.
		 * This field should be used if the data does not define the category
		 * values directly.
		 */
		public function setCategoryNames(value:Array):void
		{
			var categoryChart:ICategoryChart = this.chart as ICategoryChart;
			if(categoryChart)
			{
				categoryChart.categoryNames = value;
			}
			else
			{
				var shortName:String = ChartSerializer.getShortName(getQualifiedClassName(this.chart));
				this.log("Unable to set categoryNames on a chart of type " + shortName);
			}
		}
		
		/**
		 * Returns the field used in complex objects to access data to be
		 * displayed on the horizontal axis.
		 */
		public function getHorizontalField():String
		{
			var cartesianChart:CartesianChart = this.chart as CartesianChart;
			if(cartesianChart)
			{
				return cartesianChart.horizontalField;
			}
			
			var shortName:String = ChartSerializer.getShortName(getQualifiedClassName(this.chart));
			this.log("Unable to find horizontalField on a chart of type " + shortName);
			return null;
		}
		
		/**
		 * Sets the field used in complex objects to access data to be displayed
		 * on the horizontal axis. If the input data is XML, and the field is an
		 * attribute, be sure to include the "@" symbol at the beginning of the
		 * field name.
		 */
		public function setHorizontalField(value:String):void
		{
			var cartesianChart:CartesianChart = this.chart as CartesianChart;
			if(cartesianChart)
			{
				cartesianChart.horizontalField = value;
			}
			else
			{
				var shortName:String = ChartSerializer.getShortName(getQualifiedClassName(this.chart));
				this.log("Unable to set horizontalField on a chart of type " + shortName);
			}
		}
		
		/**
		 * Returns the field used in complex objects to access data to be
		 * displayed on the vertical axis.
		 */
		public function getVerticalField():String
		{
			var cartesianChart:CartesianChart = this.chart as CartesianChart;
			if(cartesianChart)
			{
				return cartesianChart.verticalField;
			}
			
			var shortName:String = ChartSerializer.getShortName(getQualifiedClassName(this.chart));
			this.log("Unable to find verticalField on a chart of type " + shortName);
			return null;
		}
		
		/**
		 * Sets the field used in complex objects to access data to be displayed
		 * on the vertical axis. If the input data is XML, and the field is an
		 * attribute, be sure to include the "@" symbol at the beginning of the
		 * field name.
		 */
		public function setVerticalField(value:String):void
		{
			var cartesianChart:CartesianChart = this.chart as CartesianChart;
			if(cartesianChart)
			{
				cartesianChart.verticalField = value;
			}
			else
			{
				var shortName:String = ChartSerializer.getShortName(getQualifiedClassName(this.chart));
				this.log("Unable to set verticalField on a chart of type " + shortName);
			}
		}
		
		/**
		 * Returns the title displayed next to the vertical axis.
		 */
		public function getHorizontalAxisTitle():String
		{
			var cartesianChart:CartesianChart = this.chart as CartesianChart;
			if(cartesianChart)
			{
				return cartesianChart.horizontalAxisTitle;
			}
			
			var shortName:String = ChartSerializer.getShortName(getQualifiedClassName(this.chart));
			this.log("Unable to find horizontalAxisTitle on a chart of type " + shortName);
			return null;
		}
		
		/**
		 * Sets the title displayed next to the horizontal axis.
		 */
		public function setHorizontalAxisTitle(value:String):void
		{
			var cartesianChart:CartesianChart = this.chart as CartesianChart;
			if(cartesianChart)
			{
				cartesianChart.horizontalAxisTitle = value;
			}
			else
			{
				var shortName:String = ChartSerializer.getShortName(getQualifiedClassName(this.chart));
				this.log("Unable to set horizontalAxisTitle on a chart of type " + shortName);
			}
		}
		
		/**
		 * Returns the title displayed next to the vertical axis.
		 */
		public function getVerticalAxisTitle():String
		{
			var cartesianChart:CartesianChart = this.chart as CartesianChart;
			if(cartesianChart)
			{
				return cartesianChart.verticalAxisTitle;
			}
			
			var shortName:String = ChartSerializer.getShortName(getQualifiedClassName(this.chart));
			this.log("Unable to find verticalAxisTitle on a chart of type " + shortName);
			return null;
		}
		
		/**
		 * Sets the title displayed next to the vertical axis.
		 */
		public function setVerticalAxisTitle(value:String):void
		{
			var cartesianChart:CartesianChart = this.chart as CartesianChart;
			if(cartesianChart)
			{
				cartesianChart.verticalAxisTitle = value;
			}
			else
			{
				var shortName:String = ChartSerializer.getShortName(getQualifiedClassName(this.chart));
				this.log("Unable to set verticalAxisTitle on a chart of type " + shortName);
			}
		}
		
		/**
		 * Updates the horizontal axis with a new type.
		 */
		public function setHorizontalAxis(value:Object):void
		{
			var cartesianChart:CartesianChart = this.chart as CartesianChart;
			if(cartesianChart)
			{
				cartesianChart.horizontalAxis = AxisSerializer.readAxis(value);
			}
			else
			{
				var shortName:String = ChartSerializer.getShortName(getQualifiedClassName(this.chart));
				this.log("Unable to set horizontalAxis on a chart of type " + shortName);
			}
		}
		
		/**
		 * Updates the vertical axis with a new type.
		 */
		public function setVerticalAxis(value:Object):void
		{
			var cartesianChart:CartesianChart = this.chart as CartesianChart;
			if(cartesianChart)
			{
				cartesianChart.verticalAxis = AxisSerializer.readAxis(value);
			}
			else
			{
				var shortName:String = ChartSerializer.getShortName(getQualifiedClassName(this.chart));
				this.log("Unable to set verticalAxis on a chart of type " + shortName);
			}
		}
		
		/**
		 * Sets the JavaScript function to call to generate the chart's data tip.
		 */
		public function setDataTipFunction(value:String):void
		{
			var delegate:Object = {dataTipFunction: JavaScriptUtil.createCallbackFunction(value).callback};
			delegate.callback = function(item:Object, index:int, series:ISeries):String
			{
				return delegate.dataTipFunction(item, index, SeriesSerializer.writeSeries(series));
			}
			
			this.chart.dataTipFunction = delegate.callback;
		}
		
		/**
		 * Accepts a JavaScript-friendly set of styles for the chart itself.
		 */
		public function setStyles(styles:Object):void
		{
			var contentPadding:Number = 10;
			if(styles.padding)
			{
				contentPadding = styles.padding;
			}
			
			if(styles.border)
			{
				var border:Object = styles.border;
				if(border.color != null)
				{
					this.background.borderColor = this.parseColor(border.color);
				}
				
				if(border.size != null)
				{
					this.background.borderWeight = border.size;
					contentPadding += border.size;
				}
			}
			this.chart.setStyle("contentPadding", contentPadding);
			
			if(styles.background)
			{
				var background:Object = styles.background;
				if(background.color != null)
				{
					this.background.fillColor = this.parseColor(background.color);
				}
				
				if(background.image)
				{
					this.background.image = background.image;
				}
				
				if(background.alpha != null)
				{
					this.background.fillAlpha = background.alpha;
				}
			}
			
			if(styles.font)
			{
				var textFormat:TextFormat = TextFormatSerializer.readTextFormat(styles.font);
				this.chart.setStyle("textFormat", textFormat);
			}
			
			if(styles.dataTip)
			{
				this.setDataTypeStyles(styles.dataTip);
			}
			
			if(styles.xAxis)
			{
				this.setAxisStyles(styles.xAxis, "horizontal");
			}
			
			if(styles.yAxis)
			{
				this.setAxisStyles(styles.yAxis, "vertical");
			}
			
			if(styles.animationEnabled != null)
			{
				this.chart.setStyle("animationEnabled", styles.animationEnabled);
			}
		}
		
	//--------------------------------------
	//  Protected Methods
	//--------------------------------------
		
		/**
		 * @private (protected)
		 * Initialize the functions that may be called by JavaScript through ExternalInterface.
		 */
		override protected function initializeComponent():void
		{
			
			super.initializeComponent();
			
			ExternalInterface.addCallback("setType", setType);
			ExternalInterface.addCallback("setStyles", setStyles);
			ExternalInterface.addCallback("setDataProvider", setDataProvider);
			ExternalInterface.addCallback("getCategoryNames", getCategoryNames);
			ExternalInterface.addCallback("setCategoryNames", setCategoryNames);
			ExternalInterface.addCallback("setDataTipFunction", setDataTipFunction);
			ExternalInterface.addCallback("getHorizontalField", getHorizontalField);
			ExternalInterface.addCallback("setHorizontalField", setHorizontalField);
			ExternalInterface.addCallback("getVerticalField", getVerticalField);
			ExternalInterface.addCallback("setVerticalField", setVerticalField);
			ExternalInterface.addCallback("getCategoryNames", getCategoryNames);
			ExternalInterface.addCallback("setCategoryNames", setCategoryNames);
			ExternalInterface.addCallback("setHorizontalAxis", setHorizontalAxis);
			ExternalInterface.addCallback("setVerticalAxis", setVerticalAxis);

			this.background = new BackgroundAndBorder();
			this.background.width = this.stage.stageWidth;
			this.background.height = this.stage.stageHeight;
			this.background.addEventListener(ErrorEvent.ERROR, backgroundErrorHandler);
			this.addChild(this.background);
		}
		
		/**
		 * @private (protected)
		 * Since Chart is a Flash CS3 component, we should call drawNow() to be sure it updates properly.
		 */
		override protected function refreshComponentSize():void
		{
			super.refreshComponentSize();
			
			if(this.background)
			{
				this.background.width = this.stage.stageWidth;
				this.background.height = this.stage.stageHeight;
				this.background.drawNow();
			}
			
			if(this.chart)
			{
				this.chart.drawNow();
			}
		}
		
		/**
		 * @private (protected)
		 * Logs errors for the background image loading.
		 */
		protected function backgroundErrorHandler(event:ErrorEvent):void
		{
			this.log(event.text, LoggerCategory.ERROR);
		}
		
		/**
		 * @private (protected)
		 * 
		 * Receives chart item mouse events and passes them out to JavaScript.
		 */
		protected function chartItemEventHandler(event:ChartEvent):void
		{
			var seriesIndex:int = (this.chart.dataProvider as Array).indexOf(event.series);
			var itemEvent:Object = {type: event.type, seriesIndex: seriesIndex, index: event.index};
			this.dispatchEventToJavaScript(itemEvent);
			//this.log("item event: " + event.type);
		}
		
		protected function setDataTypeStyles(styles:Object):void
		{
			var contentPadding:Number = 6;
			if(styles.padding)
			{
				contentPadding = styles.padding;
			}
			
			if(styles.border || styles.background)
			{
				var backgroundClass:Function = this.createBorderBackground();
				var border:Object = styles.border;
				if(border)
				{
					if(border.color != null)
					{
						backgroundClass.prototype.borderColor = this.parseColor(border.color)
					}
					if(border.size != null)
					{
						backgroundClass.prototype.borderWeight = border.size;
						contentPadding += border.size;
					}
				}
				var background:Object = styles.background;
				if(background)
				{
					if(background.color != null)
					{
						backgroundClass.prototype.fillColor = this.parseColor(background.color);
					}
					if(background.image)
					{
						backgroundClass.prototype.image = background.image;
					}
					if(background.alpha != null)
					{
						backgroundClass.prototype.fillAlpha = background.alpha;
					}
				}
				this.chart.setStyle("dataTipBackgroundSkin", backgroundClass);
			}
			
			this.chart.setStyle("dataTipContentPadding", contentPadding);
			
			if(styles.font)
			{
				var textFormat:TextFormat = TextFormatSerializer.readTextFormat(styles.font);
				this.chart.setStyle("dataTipTextFormat", textFormat);
			}
		}
		
		protected function setAxisStyles(styles:Object, axisName:String):void
		{
			if(styles.axis)
			{
				var axis:Object = styles.axis;
				if(axis.color != null)
				{
					this.chart.setStyle(axisName + "AxisColor", this.parseColor(axis.color));
				}
				
				if(axis.size != null)
				{
					this.chart.setStyle(axisName + "AxisWeight", axis.size);
				}
				
				if(axis.majorGridLines)
				{
					var majorGridLines:Object = axis.majorGridLines;
					if(majorGridLines.color != null)
					{
						this.chart.setStyle(axisName + "AxisGridLineColor", this.parseColor(majorGridLines.color));
					}
					if(majorGridLines.size)
					{
						this.chart.setStyle(axisName + "AxisGridLineWeight", majorGridLines.weight);
					}
				}
				
				if(axis.minorGridLines)
				{
					var minorGridLines:Object = axis.minorGridLines;
					if(minorGridLines.color != null)
					{
						this.chart.setStyle(axisName + "AxisMinorGridLineColor", this.parseColor(minorGridLines.color));
					}
					if(minorGridLines.size)
					{
						this.chart.setStyle(axisName + "AxisMinorGridLineWeight", minorGridLines.weight);
					}
				}
				
				if(axis.majorTicks)
				{
					var majorTicks:Object = axis.majorTicks;
					if(majorTicks.color != null)
					{
						this.chart.setStyle(axisName + "AxisTickColor", this.parseColor(majorTicks.color));
					}
					if(majorTicks.size != null)
					{
						this.chart.setStyle(axisName + "AxisTickWeight", majorTicks.weight);
					}
					if(majorTicks.length != null)
					{
						this.chart.setStyle(axisName + "AxisTickLength", majorTicks.length);
					}
					if(majorTicks.position)
					{
						this.chart.setStyle(axisName + "AxisTickPosition", majorTicks.position);
					}
				}
				
				if(axis.minorTicks)
				{
					var minorTicks:Object = axis.minorTicks;
					if(minorTicks.color != null)
					{
						this.chart.setStyle(axisName + "AxisMinorTickColor", this.parseColor(minorTicks.color));
					}
					if(minorTicks.size != null)
					{
						this.chart.setStyle(axisName + "AxisMinorTickWeight", minorTicks.weight);
					}
					if(minorTicks.length != null)
					{
						this.chart.setStyle(axisName + "AxisMinorTickLength", minorTicks.length);
					}
					if(minorTicks.position)
					{
						this.chart.setStyle(axisName + "AxisMinorTickPosition", minorTicks.position);
					}
				}
			}
		}
		
	//--------------------------------------
	//  Private Methods
	//--------------------------------------
		
		/**
		 * @private
		 * Creates a pseudo-class to instantiate a BackgroundAndBorder object.
		 */
		private function createBorderBackground():Function
		{
			var borderBackgroundClass:Function = function():BackgroundAndBorder
			{
				var borderBG:BackgroundAndBorder = new BackgroundAndBorder();
				borderBG.fillColor = this.fillColor;
				borderBG.fillAlpha = this.fillAlpha;
				borderBG.borderColor = this.borderColor;
				borderBG.borderWeight = this.borderWeight;
				borderBG.image = this.image;
				return borderBG;
			}
			borderBackgroundClass.prototype.fillColor = 0xffffff;
			borderBackgroundClass.prototype.fillAlpha = 1;
			borderBackgroundClass.prototype.borderColor = 0x000000;
			borderBackgroundClass.prototype.borderWeight = 1;
			borderBackgroundClass.prototype.image = null;
			return borderBackgroundClass;
		}
		
		private function parseColor(value:Object):uint
		{
			if(!(value is Number))
			{
				value = value.toString();
				if(value.indexOf("0x") != 0)
				{
					value = "0x" + value;
				}
				return parseInt(String(value), 16);
			}
			return uint(value);
		}
	}
}
