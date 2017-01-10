package hadoop;

import java.util.HashMap;
import java.util.Map;

public class DomainInfo {

	private static final String SEPARATOR = "\t";
	
	private final String[] languageSet;
	
	private Integer uriCount;
	private final Map<String, Integer> textCounts;
	private final Map<String, Long> textLengths;
	
	public DomainInfo(String[] languageSet) {
		this.languageSet = languageSet;
		
		this.uriCount = 0;
		this.textCounts = new HashMap<>(languageSet.length);
		this.textLengths = new HashMap<>(languageSet.length);
		
		for (String language : languageSet) {
			textCounts.put(language, 0);
			textLengths.put(language, 0l);
		}
	}
	
	public Integer getUriCount() {
		return uriCount;
	}
	
	public void incrementUriCount(int value) {
		uriCount += value;
	}
	
	public Integer getTextCount(String language) {
		return textCounts.get(language);
	}
	
	public void incrementTextCount(String language, int value) {
		int oldValue = textCounts.get(language);
		int newValue = oldValue + value;
		textCounts.put(language, newValue);
	}

	public Long getTextLength(String language) {
		return textLengths.get(language);
	}

	public void incrementTextLength(String language, long value) {
		long oldValue = textLengths.get(language);
		long newValue = oldValue + value;
		textLengths.put(language, newValue);
	}
	
	// Note: Below are the methods for serialization.
	
	public static String toCsv(DomainInfo domainInfo) {
		StringBuilder csvBuilder = new StringBuilder();
		
		csvBuilder.append(domainInfo.uriCount).append(SEPARATOR);
		for (String language : domainInfo.languageSet) {
			csvBuilder.append(domainInfo.textCounts.get(language)).append(SEPARATOR);
			csvBuilder.append(domainInfo.textLengths.get(language)).append(SEPARATOR);
		}
		
		csvBuilder.setLength(csvBuilder.length() - 1);
		return csvBuilder.toString();
	}
	
}
