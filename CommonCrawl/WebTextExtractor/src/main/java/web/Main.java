package web;

import org.apache.log4j.Logger;


public class Main {

	private static final Logger LOGGER = Logger.getLogger(Main.class);
	
	public static void main(String[] args) {
		try {
			Args arguments = new Args(args);
			new WebTextExtractor(arguments).run();
			System.exit(0);
			
		} catch (Exception cause) {
			LOGGER.error(cause);
			System.exit(1);
		}
	}
	
}