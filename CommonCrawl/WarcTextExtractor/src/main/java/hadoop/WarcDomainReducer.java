package hadoop;

import java.io.IOException;
import java.util.HashSet;
import java.util.Set;

import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Reducer;


public class WarcDomainReducer extends Reducer<Text, Text, Text, Text> {

	private static enum Counters {
		REDUCER_OUTPUTS
	}
	
	private Args arguments;
	
	private final Text outputKey = new Text();
	private final Text outputValue = new Text();
	
	public void setup(Context context) throws IOException, InterruptedException {
		super.setup(context);

		arguments = Args.fromConf(context.getConfiguration());
	}

	public void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException {
		Set<Integer> uriHashes = new HashSet<Integer>();
		Set<Integer> textHashes = new HashSet<Integer>();
		
		DomainInfo domainInfo = new DomainInfo(arguments.getLanguageSet());
		
		for (Text value : values) {
			TextInfo textInfo = TextInfo.fromCsv(value.toString());
			
			int uriHash = textInfo.getUri().hashCode();
			boolean hasNewUri = uriHashes.add(uriHash);
			if (hasNewUri) domainInfo.incrementUriCount(1);
			
			int textHash = textInfo.getText().hashCode();
			boolean isUniqueText = textHashes.add(textHash);
			if (!isUniqueText) continue;
			
			String language = textInfo.getLanguage();
			domainInfo.incrementTextCount(language, 1);
			
			long textLength = textInfo.getText().length();
			domainInfo.incrementTextLength(language, textLength);
		}
		
		if (!meetsDomainCriteria(domainInfo)) return;
		
		outputKey.set(key);
		outputValue.set(DomainInfo.toCsv(domainInfo));
		
		context.write(outputKey, outputValue);
		context.getCounter(Counters.REDUCER_OUTPUTS).increment(1L);
	}
		
	private boolean meetsDomainCriteria(DomainInfo domainInfo) {
		for (String language : arguments.getLanguageSet()) {
			int textCount = domainInfo.getTextCount(language);
			if (textCount < arguments.getTextCount()) return false;
		}
		
		return true;
	}
	
}
