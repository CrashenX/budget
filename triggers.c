/* Trigger to set the budget id for every transaction
 * Copyright (C) 2012 Jesse J. Cook
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#include "postgres.h"
#include "utils/builtins.h"
#include "executor/spi.h"
#include "commands/trigger.h"

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

extern Datum set_budget(PG_FUNCTION_ARGS);

PG_FUNCTION_INFO_V1(set_budget);

Datum
set_budget(PG_FUNCTION_ARGS)
{
    TriggerData *trig_data = (TriggerData *) fcinfo->context;
    TupleDesc   tup_desc;
    HeapTuple   ret_tuple, tmp_tuple;
    Datum       val;
    const char* budget_id = "budget_id";
    bool        tf_before = TRIGGER_FIRED_BEFORE    (trig_data->tg_event);
    bool        tf_row    = TRIGGER_FIRED_FOR_ROW   (trig_data->tg_event);
    bool        tf_update = TRIGGER_FIRED_BY_UPDATE (trig_data->tg_event);
    bool        tf_insert = TRIGGER_FIRED_BY_INSERT (trig_data->tg_event);
    int         col, rc;

    if(!CALLED_AS_TRIGGER(fcinfo)) {
        elog(ERROR, "set_budget: not called by trigger manager");
    }

    if(!(tf_before && tf_row && (tf_update || tf_insert))) {
        elog(ERROR, "set_budget: unsupported trigger event");
    }

    /* tuple to return to executor */
    ret_tuple = tf_update ? trig_data->tg_newtuple : trig_data->tg_trigtuple;

    tup_desc = trig_data->tg_relation->rd_att;

    if((rc = SPI_connect()) < 0) {
        elog(ERROR, "set_budget: SPI_connect error (%d)", rc);
    }

    col = SPI_fnumber(tup_desc, budget_id);
    val = Int32GetDatum(0);
    tmp_tuple = SPI_copytuple(ret_tuple);
    ret_tuple = SPI_modifytuple(trig_data->tg_relation,
                                tmp_tuple, 1, &col, &val, NULL);
    SPI_freetuple(tmp_tuple);

    SPI_finish();

    return PointerGetDatum(ret_tuple);
}
