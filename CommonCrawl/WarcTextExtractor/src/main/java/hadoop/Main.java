package hadoop;

import java.io.IOException;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.conf.Configured;
import org.apache.hadoop.fs.FileStatus;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.NullWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.mapreduce.lib.output.TextOutputFormat;
import org.apache.hadoop.util.Tool;
import org.apache.hadoop.util.ToolRunner;
import org.apache.log4j.Logger;

import com.martinkl.warc.mapreduce.WARCInputFormat;


public class Main extends Configured implements Tool {

	private static final Logger LOGGER = Logger.getLogger(Main.class);

	public static void main(String[] args) throws Exception {
		Main main = new Main();
		Configuration conf = new Configuration();
		System.exit(ToolRunner.run(conf, main, args));
	}

	public int run(String[] args) throws Exception {
		Args arguments = new Args(args);
		
		if (arguments.hasDomainsStage() && !runFilterDomains(arguments)) {
			LOGGER.error("Failed to filter domains!");
			return 1; 
		}
		
		if (arguments.hasTextsStage() && !runFilterTexts(arguments)) {
			LOGGER.error("Failed to filter texts!");
			return 1;
		}
		
		return 0;
	}
	
	private boolean runFilterDomains(Args arguments) throws Exception {
		Configuration conf = getConf();
		conf.set("mapreduce.task.timeout", "3600000");
		Args.toConf(conf, arguments);
		
		Job job = Job.getInstance(conf, "WarcTextExtractor_01");
		job.setJarByClass(Main.class);
		job.setNumReduceTasks(24);
		
		job.setInputFormatClass(WARCInputFormat.class);
		job.setOutputFormatClass(TextOutputFormat.class);

		job.setMapOutputKeyClass(Text.class);
		job.setMapOutputValueClass(Text.class);
		job.setMapperClass(WarcTextMapper.class);
		
		job.setOutputKeyClass(Text.class);
		job.setOutputValueClass(NullWritable.class);
		job.setReducerClass(WarcDomainReducer.class);
		
		Path warcsPath = new Path(arguments.getWarcsPath());
		Path domainsPath = new Path(arguments.getDomainsPath());

		FileInputFormat.addInputPath(job, warcsPath);
		FileOutputFormat.setOutputPath(job, domainsPath);
		
		return job.waitForCompletion(arguments.hasVerbose());
	}
	
	private boolean runFilterTexts(Args arguments) throws Exception {
		Configuration conf = getConf();
		conf.set("mapreduce.task.timeout", "3600000");
		Args.toConf(conf, arguments);
		
		Job job = Job.getInstance(conf, "WarcTextExtractor_02");
		job.setJarByClass(Main.class);
		job.setNumReduceTasks(24);
		
		job.setInputFormatClass(WARCInputFormat.class);
		job.setOutputFormatClass(TextOutputFormat.class);

		job.setMapOutputKeyClass(Text.class);
		job.setMapOutputValueClass(Text.class);
		job.setMapperClass(WarcTextMapper.class);
		
		job.setOutputKeyClass(Text.class);
		job.setOutputValueClass(Text.class);
		job.setReducerClass(WarcTextReducer.class);
		
		Path warcsPath = new Path(arguments.getWarcsPath());
		Path textsPath = new Path(arguments.getTextsPath());
		
		FileInputFormat.addInputPath(job, warcsPath);
		FileOutputFormat.setOutputPath(job, textsPath);
		
		if (arguments.getDomainsPath() != null) {
			Path domainsPath = new Path(arguments.getDomainsPath());
			addDomainsCacheFiles(job, domainsPath);
		}
		
		return job.waitForCompletion(arguments.hasVerbose());
	}
	
	private void addDomainsCacheFiles(Job job, Path domainsPath) throws IOException {
		Configuration conf = job.getConfiguration();
		FileSystem fileSystem = FileSystem.get(conf);
		
		for (FileStatus stat : fileSystem.listStatus(domainsPath)) {
			job.addCacheFile(stat.getPath().toUri());
		}
	}
	
}