package hadoop;

import java.util.Arrays;

import org.apache.hadoop.conf.Configuration;
import org.kohsuke.args4j.CmdLineException;
import org.kohsuke.args4j.CmdLineParser;
import org.kohsuke.args4j.Option;
import org.kohsuke.args4j.spi.BooleanOptionHandler;
import org.kohsuke.args4j.spi.DoubleOptionHandler;
import org.kohsuke.args4j.spi.IntOptionHandler;
import org.kohsuke.args4j.spi.StringArrayOptionHandler;
import org.kohsuke.args4j.spi.StringOptionHandler;


public class Args {

	private static final String WARCS_PATH_ARG = "--warcs_path";
	private static final String DOMAINS_PATH_ARG = "--domains_path";
	private static final String TEXTS_PATH_ARG = "--texts_path";
	private static final String STAGE_SET_ARG = "--stage_set";
	private static final String LANGUAGE_SET_ARG = "--language_set";
	private static final String LANGUAGE_CONFIDENCE_ARG = "--language_confidence";
	private static final String TEXT_LENGTH_ARG = "--text_length";
	private static final String TEXT_COUNT_ARG = "--text_count";
	private static final String VERBOSE_ARG = "--verbose";
	private static final String VERSION_ARG = "--version";
	private static final String HELP_ARG = "--help";

	private static final String DOMAINS_STAGE = "domains";
	private static final String TEXTS_STAGE = "texts";

	private static final String[] STAGES = { DOMAINS_STAGE, TEXTS_STAGE };	
	private static final String[] CHARSETS = { "UTF-8", "ISO-8859-1", "GB2312", "CP1251", "CP1252" };
	
	private static final String VERSION = "v0.0.1";
	
	
	@Option(
		name = WARCS_PATH_ARG,
		metaVar = "<path>", 
		usage = "warcs directory path", 
		handler = StringOptionHandler.class, 
		required = true
	)
	private String warcsPath = null;
	
	@Option(
		name = DOMAINS_PATH_ARG,
		metaVar = "<path>", 
		usage = "domains directory path", 
		handler = StringOptionHandler.class
	)
	private String domainsPath = "";
	
	@Option(
		name = TEXTS_PATH_ARG, 
		metaVar = "<path>", 
		usage = "texts directory path", 
		handler = StringOptionHandler.class
	)
	private String textsPath = "";

	@Option(
		name =  STAGE_SET_ARG,
		metaVar = "[domains|texts]",
		usage = "stages to run", 
		handler = StringArrayOptionHandler.class
	)
	private String[] stageSet = { "domains", "texts" };
	
	@Option(
		name = LANGUAGE_SET_ARG,
		metaVar = "[en|es|de|fr|cs|...]", 
		usage = "languages to consider", 
		handler = StringArrayOptionHandler.class
	)
	private String[] languageSet = { "en", "cs" };
	
	@Option(
		name = LANGUAGE_CONFIDENCE_ARG, 
		metaVar = "<double>", 
		usage = "required detection confidence", 
		handler = DoubleOptionHandler.class
	)
	private Double languageConfidence = 0.99;

	@Option(
		name = TEXT_LENGTH_ARG, 
		metaVar = "<integer>", 
		usage = "required text length", 
		handler = IntOptionHandler.class
	)
	private Integer textLength = 100;
	
	@Option(
		name = TEXT_COUNT_ARG, 
		metaVar = "<integer>",
		usage = "required text count", 
		handler = IntOptionHandler.class
	)
	private Integer textCount = 1;
	
	@Option(
		name = VERBOSE_ARG,
		metaVar = "<boolean>",
		usage = "mapreduce verbosity", 
		handler = BooleanOptionHandler.class
	)
	private Boolean verbose = true;
	
	@Option(
		name = VERSION_ARG, 
		metaVar = "<boolean>",
		usage = "print the version", 
		handler = BooleanOptionHandler.class
	)
	private Boolean version = false;
	
	@Option(
		name = HELP_ARG,
		metaVar = "<boolean>",
		usage = "print the help", 
		handler = BooleanOptionHandler.class
	)
	private Boolean help = false;	

	
	public Args(String[] args) {
		try {
			new CmdLineParser(this).parseArgument(args);
			
			if (version) System.out.println(VERSION);
			if (help) new CmdLineParser(this).printUsage(System.out);
			if (version || help) System.exit(0);
			
			validate();
			
		} catch (CmdLineException | RuntimeException cause) {
			System.err.println(cause.getMessage());
			new CmdLineParser(this).printUsage(System.err);
			System.exit(1);
		}
	}
	
	private void validate() {
		for (String stage : stageSet) { if (!Arrays.asList(STAGES).contains(stage)) 
			throw new RuntimeException("Invalid " + STAGE_SET_ARG + " value!");
		}
		
		if (hasDomainsStage() && domainsPath == null) {
			throw new RuntimeException("Required " + DOMAINS_PATH_ARG + " missing!");
		}
		
		if (hasTextsStage() && textsPath == null) {
			throw new RuntimeException("Required " + TEXTS_PATH_ARG + " missing!");
		}

		if ((languageConfidence < 0.0) || (1.0 < languageConfidence)) {
			throw new RuntimeException("Invalid " + LANGUAGE_CONFIDENCE_ARG + " value!");
		}

		if (textLength < 0) {
			throw new RuntimeException("Invalid " + TEXT_LENGTH_ARG + " value!");
		}
		
		if (textCount < 0) {
			throw new RuntimeException("Invalid " + TEXT_COUNT_ARG + " value!");
		}
	}

	public String getWarcsPath() {
		return warcsPath;
	}

	public String getDomainsPath() {
		return domainsPath;
	}

	public String getTextsPath() {
		return textsPath;
	}
	
	public String[] getStageSet() {
		return stageSet;
	}
	
	public boolean hasDomainsStage() {
		return Arrays.asList(stageSet).contains(DOMAINS_STAGE);
	}
	
	public boolean hasTextsStage() {
		return Arrays.asList(stageSet).contains(TEXTS_STAGE);
	}
	
	public String[] getLanguageSet() {
		return languageSet;
	}

	public boolean hasLanguage(String language) {
		return Arrays.asList(languageSet).contains(language);
	}
	
	public Double getLanguageConfidence() {
		return languageConfidence;
	}

	public Integer getTextLength() {
		return textLength;
	}

	public Integer getTextCount() {
		return textCount;
	}

	public boolean hasVerbose() {
		return verbose;
	}
	
	public String[] getCharsets() {
		return CHARSETS;
	}
	
	// Note: Below are the methods for serialization.
	
	public static void toConf(Configuration conf, Args args) {
		conf.set(WARCS_PATH_ARG, args.warcsPath);
		conf.set(TEXTS_PATH_ARG, args.textsPath);
		conf.set(DOMAINS_PATH_ARG, args.domainsPath);
		conf.setStrings(STAGE_SET_ARG, args.stageSet);
		conf.setStrings(LANGUAGE_SET_ARG, args.languageSet);
		conf.setDouble(LANGUAGE_CONFIDENCE_ARG, args.languageConfidence);
		conf.setInt(TEXT_LENGTH_ARG, args.textLength);
		conf.setInt(TEXT_COUNT_ARG, args.textCount);
		conf.setBoolean(VERBOSE_ARG, args.verbose);
		conf.setBoolean(VERSION_ARG, args.version);
		conf.setBoolean(HELP_ARG, args.help);
	}

	public static Args fromConf(Configuration conf) {
		Args args = new Args();
		
		args.warcsPath = conf.get(WARCS_PATH_ARG, args.warcsPath);
		args.textsPath = conf.get(TEXTS_PATH_ARG, args.textsPath);
		args.domainsPath = conf.get(DOMAINS_PATH_ARG, args.domainsPath);
		args.stageSet = conf.getStrings(STAGE_SET_ARG, args.stageSet);
		args.languageSet = conf.getStrings(LANGUAGE_SET_ARG, args.languageSet);
		args.languageConfidence = conf.getDouble(LANGUAGE_CONFIDENCE_ARG, args.languageConfidence);
		args.textLength = conf.getInt(TEXT_LENGTH_ARG, args.textLength);
		args.textCount = conf.getInt(TEXT_COUNT_ARG, args.textCount);
		args.verbose = conf.getBoolean(VERBOSE_ARG, args.verbose);
		args.version = conf.getBoolean(VERSION_ARG, args.version);
		args.help = conf.getBoolean(HELP_ARG, args.help);
		
		return args;
	}
	
	// Note: Below are the utility methods used by serialization.
	
	private Args() {
	}
	
}
