package wannabit.io.cosmostaion.model.type;

import android.util.Log;

import com.google.gson.Gson;
import com.google.gson.annotations.Expose;
import com.google.gson.annotations.SerializedName;
import com.google.gson.reflect.TypeToken;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class Result {

    @SerializedName("gas_wanted")
    public String gas_wanted;

    @SerializedName("gas_used")
    public String gas_used;


    @SerializedName("log")
    @Expose
    public Object log;

//    @SerializedName("log")
//    @Expose
//    public Log log;
//
//
//    @SerializedName("log")
//    @Expose
//    public ArrayList<Log> logs;


//    public List<Log> getValueModel() {
//        return Collections.singletonList(log);
//    }

    public boolean isSuccess() {
        boolean result = false;
        try {
            Log temp = new Gson().fromJson(new Gson().toJson(log), Log.class);
            result = temp.success;

        } catch (Exception e) {

        }
        try {
            ArrayList<Log> temp = new Gson().fromJson(new Gson().toJson(log), new TypeToken<List<Log>>(){}.getType());
            result = temp.get(0).success;

        } catch (Exception e) {

        }
        return result;
    }


    public class Log {
        @SerializedName("msg_index")
        @Expose
        public String msg_index;


        @SerializedName("success")
        @Expose
        public boolean success;


        @SerializedName("log")
        @Expose
        public String log;

    }
}
