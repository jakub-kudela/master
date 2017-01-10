package web;

import java.util.Arrays;

import org.kohsuke.args4j.CmdLineException;
import org.kohsuke.args4j.CmdLineParser;
import org.kohsuke.args4j.Option;
import org.kohsuke.args4j.spi.BooleanOptionHandler;
import org.kohsuke.args4j.spi.DoubleOptionHandler;
import org.kohsuke.args4j.spi.IntOptionHandler;
import org.kohsuke.args4j.spi.StringArrayOptionHandler;
import org.kohsuke.args4j.spi.StringOptionHandler;


public class Args {

	private static final String SEEDS_PATH_ARG = "--seeds_path";
	private static final String TEXTS_PATH_ARG = "--texts_path";
	private static final String LANGUAGE_SET_ARG = "--language_set";
	private static final String LANGUAGE_CONFIDENCE_ARG = "--language_confidence";
	private static final String TEXT_LENGTH_ARG = "--text_length";
	private static final String MAX_DEPTH_ARG = "--max_depth";
	private static final String VERBOSE_ARG = "--verbose";
	private static final String VERSION_ARG = "--version";
	private static final String HELP_ARG = "--help";
	
	private static final String[] CHARSETS = { "UTF-8", "ISO-8859-1", "GB2312", "CP1251", "CP1252" };
	
	private static final String VERSION = "v0.0.1";
	
	
	@Option(
		name = SEEDS_PATH_ARG,
		metaVar = "<path>", 
		usage = "seeds file path", 
		handler = StringOptionHandler.class, 
		required = true
	)
	private String seedsPath = null;
	
	
	@Option(
		name = TEXTS_PATH_ARG, 
		metaVar = "<path>", 
		usage = "texts file path", 
		handler = StringOptionHandler.class, 
		required = true
	)
	private String textsPath = null;
		
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
		name = MAX_DEPTH_ARG, 
		metaVar = "<integer>", 
		usage = "maximal depth factor",
		handler = IntOptionHandler.class
	)
	private Integer maxDepth = Integer.MAX_VALUE;

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
		if ((languageConfidence < 0.0) || (1.0 < languageConfidence)) {
			throw new RuntimeException("Invalid " + LANGUAGE_CONFIDENCE_ARG + " value!");
		}
		
		if (textLength < 0) {
			throw new RuntimeException("Invalid " + TEXT_LENGTH_ARG + " value!");
		}
		
		if (maxDepth < 0) {
			throw new RuntimeException("Invalid " + MAX_DEPTH_ARG + " value!");
		}
	}

	public String getSeedsPath() {
		return seedsPath;
	}

	public String getTextsPath() {
		return textsPath;
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

	public Integer getMaxDepth() {
		return maxDepth;
	}
	
	public boolean hasVerbose() {
		return verbose;
	}
	
	public String[] getCharsets() {
		return CHARSETS;
	}

}
