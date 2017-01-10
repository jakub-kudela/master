package hadoop;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URI;
import java.util.HashSet;
import java.util.Set;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Reducer;


public class WarcTextReducer extends Reducer<Text, Text, Text, Text> {

	private static enum Counters { 
		REDUCER_OUTPUTS
	}
	
	private static final String SEPARATOR = "\t";
	
	@SuppressWarnings("unused")
	
	private Args arguments;
	private Set<Integer> domainHashes;
	
	private final Text outputKey = new Text();
	private final Text outputValue = new Text();
	
	public void setup(Context context) throws IOException, InterruptedException {
		super.setup(context);

		arguments = Args.fromConf(context.getConfiguration());
		domainHashes = loadDomainHashes(context);
	}

	private Set<Integer> loadDomainHashes(Context context) throws IOException {
		Set<Integer> domainHashes = new HashSet<Integer>();
		
		Configuration conf = context.getConfiguration();
		FileSystem fileSystem = FileSystem.get(conf);
		URI[] cacheFiles = context.getCacheFiles();
		if (cacheFiles == null) return domainHashes;
		
		for (URI fileUri : cacheFiles) {
			Path filePath = new Path(fileUri);
			
			try (BufferedReader reader = new BufferedReader(
					new InputStreamReader(fileSystem.open(filePath)))) {
				
				String line = null;
				while ((line = reader.readLine()) != null) {
					String domain = line.split(SEPARATOR)[0];
					domainHashes.add(domain.hashCode());
			    }
				
			} catch (IOException | RuntimeException cause) {
				throw new RuntimeException("Failed to read domains file!", cause);
			}
		}
		
		return domainHashes;
	}
	
	public void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException {
		Set<Integer> textHashes = new HashSet<Integer>();
		
		String httpDomain = key.toString();
		if (!meetsDomainCriteria(httpDomain)) return;
		
		for (Text value : values) {
			TextInfo textInfo = TextInfo.fromCsv(value.toString());
			
			int textHash = textInfo.getText().hashCode();
			boolean isUniqueText = textHashes.add(textHash);
			if (!isUniqueText) continue;
			
			outputKey.set(key);
			outputValue.set(value);
			
			context.write(key, value);
			context.getCounter(Counters.REDUCER_OUTPUTS).increment(1L);
		}
	}
	
	private boolean meetsDomainCriteria(String httpDomain) {
		if (domainHashes.isEmpty()) return true;
		
		int httpDomainHash = httpDomain.hashCode();
		return domainHashes.contains(httpDomainHash);
	}
	
}
