import re
import csv

# Sample log data
log_data = """<INSERT YOUR LOG DATA HERE>"""

def extract_subjects_and_releases(log):
    # Regular expression to match lines indicating subjects being moved along with their release number
    pattern = r"Moving (sub-[^\s]+) from yahya/cmi_bids_(R\d+)/sub-[^\s]+ to"

    # Dictionary to hold subjects and their respective release numbers
    subjects_releases = []

    # Find all matches in the log data
    matches = re.findall(pattern, log)
    for subject, release in matches:
        subjects_releases.append((subject, release))

    return subjects_releases

# Extract subjects and their corresponding releases from the log data
subjects_releases_moved = extract_subjects_and_releases(log_data)

# Write the subject-release pairs to a CSV file
with open('subjects_moved.csv', mode='w', newline='') as file:
    writer = csv.writer(file)
    writer.writerow(['Subject ID', 'Release'])  # Writing header
    writer.writerows(subjects_releases_moved)

print("CSV file 'subjects_moved.csv' has been created with the extracted data.")
