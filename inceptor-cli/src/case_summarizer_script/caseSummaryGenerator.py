import argparse
import requests
import json
import os
from langchain_community.chat_models import ChatOllama
from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import PromptTemplate

# Assuming the above imports for LangChain are set up correctly

# https://access.redhat.com/articles/3626371

def get_access_token(offline_token):
    url = "https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token"
    payload = {'grant_type': 'refresh_token', 'client_id': 'rhsm-api', 'refresh_token': offline_token}
    response = requests.post(url, data=payload)
    response.raise_for_status()
    return response.json()['access_token']

def fetch_case_details(access_token, case_id):
    print("Colleting case comments...")
    url = f"https://api.access.redhat.com/support/v1/cases/{case_id}"
    headers = {'Authorization': f'Bearer {access_token}'}
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response.json()

def summarize_case_data(case_data):
    print("Generating case summary. This can take some time (~15-20 minutes).")
    prompt_template = """Check json sections "issue" and "comments".
    As a Tech Support Advisor, I aim to provide a comprehensive and clear summary of the case data to the customer. This summary should help the customer grasp the current situation of the case and inform them of the anticipated next steps.
    Please summarize the information provided in the "{text}" using bullet points, starting with a detailed and high-quality overview. Be sure to include actionable suggestions in the NOTES section.
    Your output should follow this template in markdown format:
    ## C.A.S.E. Update - **(case number) - (title)**
    - **Current Status**:
      - [Bullet points: Clearly describe the issue the customer is currently facing.]
    - **Actions**:
      - [Bullet points: List the actions that have been taken so far, highlighting any contributions made to resolve the issue.]
    - **Severity**:
      - [Bullet points: Evaluate and state the business impact of the issue.]
    - **Expectations**:
      - [Bullet points: Clearly outline the next steps and the expected timing for the next contact.]
    ### ENVIRONMENT:
    - [Bullet points: Mention any relevant environmental factors that could be influencing the case.]
    ### NOTES:
    - [Bullet points: Provide additional relevant information or suggestions that could aid in further understanding or resolving the case.]
    """
    prompt = PromptTemplate.from_template(prompt_template)
    #llm = ChatOllama(model="llama3", temperature=0)
    llm = ChatOllama(model="wizardlm2", temperature=0, num_ctx=8192, top_k=10)
    llm_chain = prompt | llm | StrOutputParser()
    summarized_text = llm_chain.invoke(json.dumps(case_data))
    return summarized_text

def main():
    # Read case_id as a command-line argument
    parser = argparse.ArgumentParser(description="Process case_id and offline token.")
    parser.add_argument('case_id', type=str, help='The case ID to process')
    args = parser.parse_args()
    
    # Store the case_id in a variable
    case_id = args.case_id

    # Prompt the user to navigate to a link, generate a token, and paste it in the terminal
    print("Please navigate to the following link and click on `Generate Token` to generate your token:")
    print("https://access.redhat.com/management/api")
    
    # Read the token input from the user
    offline_token = input("Paste the generated token here: ")
    
    # Set the environment variable
    os.environ['RH_API_OFFLINE_TOKEN'] = offline_token

    offline_token = os.environ['RH_API_OFFLINE_TOKEN']
    access_token = get_access_token(offline_token)
    cases_data = {}
    
    try:
        case_data = fetch_case_details(access_token, case_id)
        print(summarize_case_data(case_data))
    except requests.HTTPError as e:
        print(f"HTTP error for case {case_id}: {e.response.status_code} - {e.response.text}")
    except Exception as e:
        print(f"An error occurred for case {case_id}: {e}")
    return cases_data

# Run the main function and print results
cases_summaries = main()
