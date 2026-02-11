# Making it easier to check if pre-reqs are satisfied prior to an install

This is a work in progress, check back later :-)


## Set up Claude 

Configure Claude Code to use Posit's approved AWS Bedrock instance: <https://positpbc.atlassian.net/wiki/x/IAD4Yw>

Install Claude Code:

```bash
npm install -g @anthropic-ai/claude-code
```

Find the path where it was installed: `npm config get prefix` 

- If it returns /usr/local: The binary should be in /usr/local/bin.

- If it returns a path in your home folder (e.g., /home/user/.npm-global): The binary is in that folder's /bin sub-directory.

Update zhrc / .bashrc is in my home directory as a hidden file: `nano ~/.bashrc`

```bash
export PATH="/home/lisa/.npm-global/bin:$PATH"
#export AWS_REGION=us-east-2
#export CLAUDE_CODE_USE_BEDROCK=1
#export ANTHROPIC_MODEL='us.anthropic.claude-sonnet-4-20250514-v1:0'
```

And then source your bashrc: `source ~/.bashrc`

You might need to update your `~/.aws/config` file to add a new profile, e.g.:

```bash
[profile claude]
sso_session = posit
sso_account_id = <redacted>
sso_role_name = Claude
region = us-east-2
```

To use this profile, specify the profile name using --profile, as shown: `aws sts get-caller-identity--profile claude`

You will also need to edit your `~/.claude/settings.json` (if the file does not already exist, create it):

```bash
{
  "awsAuthRefresh": "aws sso login",
  "env": {
    "CLAUDE_CODE_USE_BEDROCK": 1,
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "4096",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "us.anthropic.claude-opus-4-1-20250805-v1:0",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "us.anthropic.claude-haiku-4-5-20251001-v1:0",
    "CLAUDE_CODE_SUBAGENT_MODEL": "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
    "ANTHROPIC_MODEL": "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
    "ANTHROPIC_SMALL_FAST_MODEL": "us.anthropic.claude-3-5-haiku-20241022-v1:0",
    "MAX_THINKING_TOKENS": "1024",
    "AWS_PROFILE": "claude",
    "AWS_REGION": "us-east-1"
  }
}
```

In cases where a browser is not available (like headless or server-only environments) then use the awsCredentialExport property instead. This only works after aws sso login is successful, and invokes the export-credentials command to read the current profile’s credentials. EG `"awsCredentialExport": "aws configure export-credentials", ` instead of `"awsAuthRefresh": "aws sso login",`

## Log in to AWS

```bash
aws-assume team-east-2 # us-east-2 Choose this one
aws sso login
aws sts get-caller-identity
claude
claude --permission-mode plan
```

## Usage

Start Claude Code in planning mode:

```bash
claude --permission-mode plan
```

## Inspiration

This is cool (Sam E's): <https://github.com/posit-dev/posit-claude-internal-support-tool>
