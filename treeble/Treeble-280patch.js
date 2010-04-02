(function(){


/**
 * This is only needed for local data sources or when paginating only
 * top-level nodes, and it will be obsolete when YUI 2.9 is released.
 *
 * @module Treeble
 * @namespace YAHOO.widget
 * @class YAHOO.widget.DataTable
 */

	var lang   = YAHOO.lang,
		util   = YAHOO.util,
		widget = YAHOO.widget,
		ua     = YAHOO.env.ua,

		Dom    = util.Dom,
		Ev     = util.Event,
		DS     = util.DataSourceBase,
		DT     = widget.DataTable;

	YAHOO.widget.DataTable.prototype.load = function(oConfig) {
		oConfig = oConfig || {};

		(oConfig.datasource || this._oDataSource).sendRequest(
			oConfig.request || this.get('initialRequest'),
			oConfig.callback || {
				success: this.onDataReturnInitializeTable,
				failure: this.onDataReturnInitializeTable,
				scope: this,
				argument: this.getState()
			}
		);
	};

	var origInitAttributes = YAHOO.widget.DataTable.prototype.initAttributes;
	YAHOO.widget.DataTable.prototype.initAttributes = function()
	{
		origInitAttributes.apply(this, arguments);

		/**
		 * @attribute displayAllRecords
		 * @description Set to true if you want to show all the records that were
		 * returned, not just the records that fall inside the paginator window.
		 * @type Boolean
		 * @default 0
		 */
		this.setAttributeConfig("displayAllRecords", {
			value: false,
			validator: lang.isBoolean
		});
	};

	/**
	 * Override to provide option to display all returned records, even if
	 * that is more than what paginator says is visible.
	 *
	 * @method render
	 */
	YAHOO.widget.DataTable.prototype. render = function() {

		this._oChainRender.stop();

		this.fireEvent("beforeRenderEvent");

		var i, j, k, len, allRecords;

		var oPaginator = this.get('paginator');
		// Paginator is enabled, show a subset of Records and update Paginator UI
		if(oPaginator && this.get('displayAllRecords')) {
			allRecords = this._oRecordSet.getRecords(
							oPaginator.getStartIndex());
		}
		else if(oPaginator) {
			allRecords = this._oRecordSet.getRecords(
							oPaginator.getStartIndex(),
							oPaginator.getRowsPerPage());
		}
		// Not paginated, show all records
		else {
			allRecords = this._oRecordSet.getRecords();
		}

		// From the top, update in-place existing rows, so as to reuse DOM elements
		var elTbody = this._elTbody,
			loopN = this.get("renderLoopSize"),
			nRecordsLength = allRecords.length;

		// Table has rows
		if(nRecordsLength > 0) {
			elTbody.style.display = "none";
			while(elTbody.lastChild) {
				elTbody.removeChild(elTbody.lastChild);
			}
			elTbody.style.display = "";

			// Set up the loop Chain to render rows
			this._oChainRender.add({
				method: function(oArg) {
					if((this instanceof DT) && this._sId) {
						var i = oArg.nCurrentRecord,
							endRecordIndex = ((oArg.nCurrentRecord+oArg.nLoopLength) > nRecordsLength) ?
									nRecordsLength : (oArg.nCurrentRecord+oArg.nLoopLength),
							elRow, nextSibling;

						elTbody.style.display = "none";

						for(; i<endRecordIndex; i++) {
							elRow = Dom.get(allRecords[i].getId());
							elRow = elRow || this._addTrEl(allRecords[i]);
							nextSibling = elTbody.childNodes[i] || null;
							elTbody.insertBefore(elRow, nextSibling);
						}
						elTbody.style.display = "";

						// Set up for the next loop
						oArg.nCurrentRecord = i;
					}
				},
				scope: this,
				iterations: (loopN > 0) ? Math.ceil(nRecordsLength/loopN) : 1,
				argument: {
					nCurrentRecord: 0,//nRecordsLength-1,  // Start at first Record
					nLoopLength: (loopN > 0) ? loopN : nRecordsLength
				},
				timeout: (loopN > 0) ? 0 : -1
			});

			// Post-render tasks
			this._oChainRender.add({
				method: function(oArg) {
					if((this instanceof DT) && this._sId) {
						while(elTbody.rows.length > nRecordsLength) {
							elTbody.removeChild(elTbody.lastChild);
						}
						this._setFirstRow();
						this._setLastRow();
						this._setRowStripes();
						this._setSelections();
					}
				},
				scope: this,
				timeout: (loopN > 0) ? 0 : -1
			});

		}
		// Table has no rows
		else {
			// Set up the loop Chain to delete rows
			var nTotal = elTbody.rows.length;
			if(nTotal > 0) {
				this._oChainRender.add({
					method: function(oArg) {
						if((this instanceof DT) && this._sId) {
							var i = oArg.nCurrent,
								loopN = oArg.nLoopLength,
								nIterEnd = (i - loopN < 0) ? -1 : i - loopN;

							elTbody.style.display = "none";

							for(; i>nIterEnd; i--) {
								elTbody.deleteRow(-1);
							}
							elTbody.style.display = "";

							// Set up for the next loop
							oArg.nCurrent = i;
						}
					},
					scope: this,
					iterations: (loopN > 0) ? Math.ceil(nTotal/loopN) : 1,
					argument: {
						nCurrent: nTotal,
						nLoopLength: (loopN > 0) ? loopN : nTotal
					},
					timeout: (loopN > 0) ? 0 : -1
				});
			}
		}
		this._runRenderChain();
	};

})();
